# encoding: utf-8
require 'rubygems'
require 'boxr'
require 'mechanize'

module CarrierWave
	module Storage
		class Box < Abstract
			# Stubs we must implement to create and save

			# Store a single file
			def store!(file)
				# Try to create folders
				create_folders_from_path(uploader.store_dir)

				# Upload file
				begin
					folder_will_up = client.folder_from_path(uploader.store_dir)
					file_up = client.upload_file(file.to_file, folder_will_up)
				rescue Boxr::BoxrError => e
					if e.message.include?('409')
						# File exists. Delete it
						file_temp = client.file_from_path("#{uploader.store_dir}/#{file.filename}")
						client.delete_file(file_temp, if_match: nil)

						# Create new one
						file_up = client.upload_file(file.to_file, folder_will_up)
					end
				end

				file
			end

			# Retrieve a single file
			def retrieve!(file)
				CarrierWave::Storage::Box::File.new(uploader, uploader.store_path(file), client)
			end

			private

			def client
				@client ||= Carrierwave::Box::Client.new(uploader)
			end

			def create_folders_from_path(path)
				folders = path.split('/')
				folders.each_with_index do |f, i|
					begin
						if i == 0 
							client.create_folder(f, Boxr::ROOT)
						else
							parent = client.folder_from_path(folders[0..i-1].join('/'))
							client.create_folder(f, parent)
						end
					rescue
						next
					end
				end
				
			end

			class File
				include CarrierWave::Utilities::Uri
				attr_reader :path

				def initialize(uploader, path, client)
					@uploader, @path, @client = uploader, path, client
				end

				def url(options = {})
					@client.download_url(file_info, options.merge(version: nil))
				end

				def read
					@client.download_file(file_info, version: nil, follow_redirect: true)
				end

				def to_s
					url ||= ''
				end

				def delete
					file_temp = @client.file_from_path(@path)
					@client.delete_file(file_temp, if_match: nil)
					cache_method_clear :file_info
					cache_method_clear :url
				rescue Boxr::BoxrError => e
				end

				def as_cache_key
    			path
  			end

				private

				def file_info
					@client.file_from_path(path)
				end
				cache_method :file_info

			end
		end
	end
end
