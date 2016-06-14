module Carrierwave
  module Box
    class Client
      attr_reader :uploader

      def initialize(uploader)
        @uploader = uploader
      end

      def client
        @client ||= jwt_private_key.present? ? Boxr::Client.new(box_jwt_access_token) : Boxr::Client.new(box_access_token)
      end

      private

      def link_out client_id
        "https://www.box.com/api/oauth2/authorize?client_id=#{client_id}&redirect_uri=http%3A%2F%2Flocalhost&response_type=code"
      end

      def box_access_token
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
        Boxr::get_tokens(code, grant_type: "authorization_code", assertion: nil, scope: nil, username: nil, client_id: uploader.box_client_id, client_secret: uploader.box_client_secret).access_token
      end
      cache_method :box_access_token, 1.hour

      def jwt_private_key
        @jwt_private_key ||= uploader.jwt_private_key || (uploader.jwt_private_key_path.present? ? ::File.read(uploader.jwt_private_key_path) : nil)
      end

      def box_jwt_access_token
        token = Boxr::get_user_token(uploader.jwt_user_id, {
          private_key: jwt_private_key,
          private_key_password: uploader.jwt_private_key_password,
          public_key_id: uploader.jwt_public_key_id,
          client_id: uploader.box_client_id,
          client_secret: uploader.box_client_secret
        })

        token.access_token
      end
      cache_method :box_jwt_access_token, 1.hour

      def method_missing(method, *args, &block)
        client.send(method, *args, &block)
      rescue Boxr::BoxrError => e
        reset_client
        client.send(method, *args, &block)
      end

      def reset_client
        cache_method_clear :box_jwt_access_token
        cache_method_clear :box_access_token
        @client = nil
      end

    end
  end
end