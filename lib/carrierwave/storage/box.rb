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
			def link_out client_id
				"https://www.box.com/api/oauth2/authorize?client_id=#{client_id}&redirect_uri=http%3A%2F%2Flocalhost&response_type=code"
			end

			def client
				@client ||= jwt_private_key.present? ? box_client_jwt : box_client
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
				token = Boxr::get_user_token(uploader.jwt_user_id, {
						private_key: jwt_private_key,
						private_key_password: uploader.jwt_private_key_password,
						client_id: uploader.box_client_id,
						client_secret: uploader.box_client_secret
					})
				Boxr::Client.new(token.access_token)
			end

			def jwt_private_key
				@jwt_private_key ||= uploader.jwt_private_key || (uploader.jwt_private_key_path.present? ? ::File.read(uploader.jwt_private_key_path) : nil)
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

				def url
					file_temp = @client.file_from_path(path)
					@client.download_url(file_temp, version: nil)
				end

				def to_s
					url ||= ''
				end

				def delete
					file_temp = @client.file_from_path(@path)
					@client.delete_file(file_temp, if_match: nil)
				rescue Boxr::BoxrError => e
				end

			end
		end
	end
end
