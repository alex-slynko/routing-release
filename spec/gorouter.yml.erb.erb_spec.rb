# rubocop:disable LineLength
# rubocop:disable BlockLength
require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'

TEST_CERT = 'some

multiline

cert'.freeze

TEST_KEY = 'some

multi line key'.freeze

describe 'gorouter.yml.erb' do
  let(:deployment_manifest_fragment) do
    {
        'router' => {
          'status' => {
            'port' => 80,
            'user' => 'test',
            'password' => 'pass'
          },
          'enable_ssl' => true,
          'tls_port' => 443,
          'client_cert_validation' => 'none',
          'logging_level' => 'info',
          'tracing' => {
            'enable_zipkin' => false
          },
          'ssl_skip_validation' => false,
          'port' => 80,
          'offset' => 0,
          'number_of_cpus' => 0,
          'trace_key' => 'key',
          'debug_address' => '127.0.0.1',
          'secure_cookies' => false,
          'write_access_logs_locally' => true,
          'access_log' => {
            'enable_streaming' => false
          },
          'drain_wait' => 10,
          'healthcheck_user_agent' => 'test-agent',
          'requested_route_registration_interval_in_seconds' => 10,
          'load_balancer_healthy_threshold' => 10,
          'balancing_algorithm' => 'round-robin',
          'disable_log_forwarded_for' => true,
          'disable_log_source_ip' => true,
          'tls_pem' => [
            {
              'cert_chain' => 'test-chain',
              'private_key' => 'test-key'
            },
            {
              'cert_chain' => 'test-chain2',
              'private_key' => 'test-key2'
            }
          ],
          'min_tls_version' => 1.2,
          'disable_http' => false,
          'ca_certs' => 'test-certs',
          'cipher_suites' => 'test-suites',
          'forwarded_client_cert' => ['test-cert'],
          'isolation_segments' => '[is1]',
          'routing_table_sharding_mode' => 'sharding',
          'route_services_timeout' => 10,
          'route_services_secret' => 'secret',
          'route_services_secret_decrypt_only' => 'secret',
          'route_services_recommend_https' => false,
          'extra_headers_to_log' => 'test-header',
          'enable_proxy' => false,
          'force_forwarded_proto_https' => false,
          'sanitize_forwarded_proto' => false,
          'suspend_pruning_if_nats_unavailable' => false,
          'max_idle_connections' => 100,
          'backends' => {
            'max_conns' => 100,
            'cert_chain' => TEST_CERT,
            'private_key' => TEST_KEY
          },
          'frontend_idle_timeout' => 5,
          'ip_local_port_range' => '1024 65535'
        },
        'request_timeout_in_seconds' => 100,
        'routing_api' => {
          'enabled' => false
        },
        'uaa' => {
          'ca_cert' => 'blah-cert',
          'ssl' => {
            'port' => 900
          },
          'clients' => {
            'gorouter' => {
              'secret' => 'secret'
            }
          },
          'token_endpoint' => 'uaa.token_endpoint'
        },
        'nats' => {
          'machines' => ['127.0.0.1'],
          'port' => 8080,
          'user' => 'test',
          'password' => 'test_pass'
        },
        'metron' => {
          'port' => 3745
        }
    }
  end

  let(:release_path) {File.join(File.dirname(__FILE__), '..')}
  let(:release) {Bosh::Template::Test::ReleaseDir.new(release_path)}
  let(:job) {release.job('gorouter')}

  subject(:parsed_yaml) do
    template = job.template('config/gorouter.yml')
    
    YAML.safe_load(template.render(deployment_manifest_fragment))
  end

  context 'given a generally valid manifest' do
    describe 'client_cert_validation' do
      context 'when no override is provided' do
        it 'should default to none' do
          expect(parsed_yaml['client_cert_validation']).to eq('none')
        end
      end

      context 'when the value is not valid' do
        before do
          deployment_manifest_fragment['router']['client_cert_validation'] = 'meow'
        end
        it 'should error' do
          expect { raise parsed_yaml }.to raise_error(RuntimeError, 'router.client_cert_validation must be "none", "request", or "require"')
        end
      end
    end

    context 'tls_pem' do
      context 'when correct tls_pem is provided' do
        it 'should configure the property' do
          expect(parsed_yaml['tls_pem'].length).to eq(2)
          expect(parsed_yaml['tls_pem'][0]).to eq('cert_chain' => 'test-chain',
                                                  'private_key' => 'test-key')
          expect(parsed_yaml['tls_pem'][1]).to eq('cert_chain' => 'test-chain2',
                                                  'private_key' => 'test-key2')
        end
      end

      context 'when an incorrect tls_pem value is provided with missing cert' do
        before do
          deployment_manifest_fragment['router']['tls_pem'] = [{ 'private_key' => 'test-key' }]
        end
        it 'should error' do
          expect { raise parsed_yaml }.to raise_error(RuntimeError, 'must provide cert_chain and private_key with tls_pem')
        end
      end

      context 'when an incorrect tls_pem value is provided with missing key' do
        before do
          deployment_manifest_fragment['router']['tls_pem'] = [{ 'cert_chain' => 'test-chain' }]
        end
        it 'should error' do
          expect { raise parsed_yaml }.to raise_error(RuntimeError, 'must provide cert_chain and private_key with tls_pem')
        end
      end

      context 'when an incorrect tls_pem value is provided as wrong format' do
        before do
          deployment_manifest_fragment['router']['tls_pem'] = ['cert']
        end
        it 'should error' do
          expect { raise parsed_yaml }.to raise_error(RuntimeError, 'must provide cert_chain and private_key with tls_pem')
        end
      end
    end
    describe 'backends' do
      context 'when both cert_chain and private_key are provided' do
        it 'should configure the property' do
          expect(parsed_yaml['backends']['cert_chain']).to eq(TEST_CERT)
          expect(parsed_yaml['backends']['private_key']).to eq(TEST_KEY)
        end
      end
      context 'when cert_chain is provided but not private_key' do
        before do
          deployment_manifest_fragment['router']['backends']['private_key'] = nil
        end
        it 'should error' do
          expect { raise parsed_yaml }.to raise_error(RuntimeError, 'backends.cert_chain and backends.private_key must be both provided or not at all')
        end
      end
      context 'when private_key is provided but not cert_chain' do
        before do
          deployment_manifest_fragment['router']['backends']['cert_chain'] = nil
        end
        it 'should error' do
          expect { raise parsed_yaml }.to raise_error(RuntimeError, 'backends.cert_chain and backends.private_key must be both provided or not at all')
        end
      end
      context 'when neither cert_chain nor private_key are provided' do
        before do
          deployment_manifest_fragment['router']['backends']['cert_chain'] = nil
          deployment_manifest_fragment['router']['backends']['private_key'] = nil
        end
        it 'should not error and should not configure the properties' do
          expect(parsed_yaml['backends']['cert_chain']).to eq('')
          expect(parsed_yaml['backends']['private_key']).to eq('')
        end
      end
    end

    context 'ca_certs' do
      context 'when correct ca_certs is provided' do
        it 'should configure the property' do
          expect(parsed_yaml['ca_certs']).to eq('test-certs')
        end
      end
      context 'when ca_certs is blank' do
        before do
          deployment_manifest_fragment['router']['ca_certs'] = nil
        end
        it 'returns a helpful error message' do
          expect { raise parsed_yaml }.to raise_error(/Can\'t find property \'\[\"router.ca_certs\"\]\'/)
        end
      end
      context 'when a simple array is provided' do
        before do
          deployment_manifest_fragment['router']['ca_certs'] = ['some-tls-cert']
        end
        it 'raises error' do
          expect { raise parsed_yaml }.to raise_error(RuntimeError, 'ca_certs must be provided as a single string block')
        end
      end
      context 'when an empty array is provided' do
        before do
          deployment_manifest_fragment['router']['ca_certs'] = []
        end
        it 'raises error' do
          expect { raise parsed_yaml }.to raise_error(RuntimeError, 'ca_certs must be provided as a single string block')
        end
      end
      context 'when set to a multi-line string' do
        let(:test_certs) do
          '
some
multi
line

string
with lots

o

whitespace

      '
        end

        before do
          deployment_manifest_fragment['router']['ca_certs'] = test_certs
        end
        it 'suceessfully configures the property' do
          expect(parsed_yaml['ca_certs']).to eq(test_certs)
        end
      end
    end
  end
end
