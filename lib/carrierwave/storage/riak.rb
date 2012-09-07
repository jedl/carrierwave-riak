# encoding: utf-8
require 'carrierwave'
require 'riak'

module CarrierWave
  module Storage

    ##
    #
    #     CarrierWave.configure do |config|
    #       config.riak_host = "http://localhost
    #       config.riak_port = 8098
    #     end
    #
    #
    class Riak < Abstract

      class Connection
        def initialize(options={})
          @riak_bucket = options[:riak_bucket]
          @host = options[:riak_host]
          @port = options[:riak_port]
          @client = ::Riak::Client.new(:host => @host, :http_port => @port)
        end

        def store(bucket, key, payload, headers = {})
          bucket = @client.bucket(bucket)
          robject = ::Riak::RObject.new(bucket, key)
          robject.content_type = headers[:content_type]
          robject.raw_data = payload
          robject.store
        end

        def get(bucket, key)
          bucket = @client.bucket(bucket)
          bucket.get(key)
        end

        def delete(bucket, key)
          bucket = @client.bucket(bucket)
          bucket.delete(key)
        end

        def post(path, payload, headers = {})
          @http["#{escaped(path)}"].post(payload, headers)
        end

        def escaped(path)
          CGI.escape(path)
        end
        
      end

      class File
        attr_accessor :bucket, :key
        
        def initialize(uploader, base, bucket, key)
          @uploader = uploader
          @bucket = bucket
          @key = key
          @base = base
        end

        ##
        # Returns the bucket of the riak file
        #
        # === Returns
        #
        # [String] A filename
        #
        def bucket
          @bucket
        end

        ##
        # Returns the key of the riak file
        #
        # === Returns
        #
        # [String] A filename
        #
        def key
          @key
        end

        ##
        # Lookup value for file content-type header
        #
        # === Returns
        #
        # [String] value of content-type
        #
        def content_type
          @content_type || file.content_type
        end

        ##
        # Set non-default content-type header (default is file.content_type)
        #
        # === Returns
        #
        # [String] returns new content type value
        #
        def content_type=(new_content_type)
          @content_type = new_content_type
        end

        ##
        # Return riak meta data
        #
        # === Returns
        #
        # [Haash] A hash of X-Riak-Meta-* headers
        #
        def meta
          file.meta
        end

        ##
        # Return size of file body
        #
        # === Returns
        #
        # [Integer] size of file body
        #
        def size
          file.raw_data.length
        end

        ##
        # Reads the contents of the file from Riak
        #
        # === Returns
        #
        # [String] contents of the file
        #
        def read
          file.raw_data
        end

        ##
        # Remove the file from Riak
        #
        def delete
          begin
            riak_client.delete(@bucket, @key)
            true
          rescue Exception => e
            # If the file's not there, don't panic
            nil
          end
        end

        ##
        # Writes the supplied data into Riak
        #
        # === Returns
        #
        # boolean
        #
        def store(file)
          @file = riak_client.store(@bucket, file.filename, file.read, {:content_type => file.content_type})
          @key = file.filename
          true
        end
        
        
        def url(options = {})
          "#{@uploader.riak_host}:#{@uploader.riak_port}/riak/#{@bucket}/#{@key}"
        end

        def path
          # Specifying Object to designate Ruby's top level File class, not the class in which this method is definec (CarrierWave::Storage::Riak::File)
          Object::File.join([@bucket, @key])
        end

        def filename
          @key
        end

        private

          def headers
            @headers ||= {  }
          end

          def connection
            @base.connection
          end

          ##
          # lookup file
          #
          # === Returns
          #
          # [Riak::RObject] file data from remote service
          #
          def file
            @file ||= riak_client.get(@bucket, @key)
          end

          def riak_client
            if @riak_client
              @riak_client
            else
              config = {
                :riak_bucket => @uploader.riak_bucket,
                :riak_host => @uploader.riak_host,
                :riak_port => @uploader.riak_port
              }
              @riak_client ||= CarrierWave::Storage::Riak::Connection.new(config)
            end
          end

      end

      ##
      # Store the file on Riak
      #
      # === Parameters
      #
      # [file (CarrierWave::SanitizedFile)] the file to store
      #
      # === Returns
      #
      # [CarrierWave::Storage::Riak::File] the stored file
      #
      def store!(file)
        # f = CarrierWave::Storage::Riak::File.new(uploader, self, uploader.bucket, uploader.key)
        puts "!!!!!!!!!!!!!!!!!!!!!!! bucket"
        puts uploader.bucket
        f = CarrierWave::Storage::Riak::File.new(uploader, self, uploader.bucket, uploader.get_full_filename(filename))
        f.store(file)
        f
      end

      # Do something to retrieve the file
      #
      # @param [String] identifier uniquely identifies the file
      #
      # [identifier (String)] uniquely identifies the file
      #
      # === Returns
      #
      # [CarrierWave::Storage::Riak::File] the stored file
      #
      def retrieve!(key)
        # CarrierWave::Storage::Riak::File.new(uploader, self, uploader.bucket, key)
        CarrierWave::Storage::Riak::File.new(uploader, self, uploader.bucket, uploader.get_full_filename(key))
      end

      def identifier
        uploader.key
      end

    end # CloudFiles
  end # Storage
end # CarrierWave
