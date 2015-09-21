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
				client = uploader.jwt_private_key_path.present? ? box_client_jwt : box_client

				# Try to create folders
				create_folders_from_path(uploader.store_dir, client)

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
				client = uploader.jwt_private_key_path.present? ? box_client_jwt : box_client
				CarrierWave::Storage::Box::File.new(uploader, config, uploader.store_path(file), client)
			end

			private
			def link_out client_id
				"https://www.box.com/api/oauth2/authorize?client_id=#{client_id}&redirect_uri=http%3A%2F%2Flocalhost&response_type=code"
			end

			def box_client
				@mechanize = Mechanize.new
				page = @mechanize.get(link_out(uploader.box_client_id))
				@mechanize.follow_meta_refresh = true
				form = page.form
				form.login = uploader.box_email
				form.password = uploader.box_password
				page1 = form.submit
				form1 = page1.form
				page_next = form1.submit
				code = page_next.uri.to_s.split('code=').last				
				token = Boxr::get_tokens(code, grant_type: "authorization_code", assertion: nil, scope: nil, username: nil, client_id: uploader.box_client_id, client_secret: uploader.box_client_secret).access_token
				Boxr::Client.new(token)
			end

			def box_client_jwt
				token = Boxr::get_enterprise_token(private_key: IO.readlines(uploader.jwt_private_key_path).map{|l| l}.join, private_key_password: uploader.jwt_private_key_password, enterprise_id: uploader.box_enterprise_id, client_id: uploader.box_client_id, client_secret: uploader.box_client_secret)
				Boxr::Client.new(token)
			end

			def config
				@config ||= {}

				@config[:box_client_id] ||= uploader.box_client_id
				@config[:box_client_secret] ||= uploader.box_client_secret
				@config[:box_email] ||= uploader.box_email
				@config[:box_password] ||= uploader.box_password
				@config[:box_access_type] ||= uploader.box_access_type || "box"


				@config[:jwt_private_key_path] ||= uploader.jwt_private_key_path
				@config[:jwt_private_key_password] ||= uploader.jwt_private_key_password
				@config[:box_enterprise_id] ||= uploader.box_enterprise_id

				@config
			end

			def create_folders_from_path(path, client)
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

				def initialize(uploader, config, path, client)
					@uploader, @config, @path, @client = uploader, config, path, client
				end

				def url
					file_temp = @client.file_from_path(path)
					file = @client.download_url(file_temp, version: nil)
				end

				def to_s
					url ||= ''
				end

				def delete					
					begin
						file_temp = @client.file_from_path(@path)
						@client.delete_file(file_temp, if_match: nil)
					rescue Boxr::BoxrError => e
					end
				end
			end
		end
	end
end
