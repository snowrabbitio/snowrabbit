require 'openssl'

def generate_ssl_certificate
  # Generate a key pair (private and public key)
  key = OpenSSL::PKey::RSA.new(2048)

  # Create a new certificate
  certificate = OpenSSL::X509::Certificate.new

  # Set the version (X.509 v3)
  certificate.version = 2

  # Set the certificate's serial number
  certificate.serial = Random.rand(10_000)

  # Set the certificate's subject (e.g., details about the owner of the certificate)
  subject = OpenSSL::X509::Name.new([
    ['C',  'US'],
    ['ST', 'State'],
    ['L',  'City'],
    ['O',  'Organization'],
    ['OU', 'Organizational Unit'],
    ['CN', 'Common Name'] # e.g., domain name
  ])
  certificate.subject = subject

  # Set the issuer (for self-signed, it's the same as the subject)
  certificate.issuer = subject

  # Set the validity period
  certificate.not_before = Time.now
  certificate.not_after = Time.now + (365 * 24 * 60 * 60) # 1 year validity
  
  # Set the public key of the certificate
  certificate.public_key = key.public_key

  # Add an extension for the certificate to be used as a CA certificate (optional)
  ef = OpenSSL::X509::ExtensionFactory.new
  ef.subject_certificate = certificate
  ef.issuer_certificate = certificate
  certificate.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))

  # Sign the certificate with the private key
  certificate.sign(key, OpenSSL::Digest.new('SHA256'))

  [key.to_pem, certificate.to_pem]
end

def set_thin_certificate
  ssl_cert = generate_ssl_certificate

  ssl_context = OpenSSL::SSL::SSLContext.new
  ssl_context.cert = OpenSSL::X509::Certificate.new(ssl_cert[1])
  ssl_context.key = OpenSSL::PKey::RSA.new(ssl_cert[0])

  # Pass the SSL context to Thin
  Thin::Server.class_eval do
    def ssl_context
      @ssl_context ||= ssl_context
    end
  end
end

