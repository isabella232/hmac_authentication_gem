require 'base64'
require 'openssl'

module HmacAuthentication
  class HmacAuth
    attr_reader :digest, :secret_key, :signature_header, :headers

    NO_SIGNATURE = 1
    INVALID_FORMAT = 2
    UNSUPPORTED_ALGORITHM = 3
    MATCH = 4
    MISMATCH = 5

    def initialize(digest, secret_key, signature_header, headers)
      @digest = parse_digest digest
      @secret_key = secret_key
      @signature_header = signature_header
      @headers = headers
    end

    def signed_headers(request)
      headers.map { |name| (request.get_fields(name) || []).join(',') }
    end
    private :signed_headers

    def hash_url(req)
      result = "#{req.uri.path}"
      result << '?' << req.uri.query if req.uri.query
      result << '#' << req.uri.fragment if req.uri.fragment
      result
    end
    private :hash_url

    def string_to_sign(req)
      [req.method, signed_headers(req).join("\n"), hash_url(req)].join("\n")
    end

    def request_signature(request)
      hmac = OpenSSL::HMAC.new secret_key, digest
      hmac << string_to_sign(request) << (request.body || '')
      digest.name.downcase + ' ' + Base64.strict_encode64(hmac.digest)
    end

    def parse_digest(name)
      OpenSSL::Digest.new name
    rescue
      nil
    end
    private :parse_digest

    def validate_request(request)
      header = request[signature_header]
      return NO_SIGNATURE unless header
      components = header.split ' '
      return INVALID_FORMAT, header unless components.size == 2
      digest = parse_digest components.first
      return UNSUPPORTED_ALGORITHM, header unless digest
      computed = request_signature request
      [(header == computed) ? MATCH : MISMATCH, header, computed]
    end
  end
end
