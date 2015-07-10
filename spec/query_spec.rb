require 'spec_helper'

RSpec.describe Elasticband::Query do
  describe '#to_h' do
    subject { described_class.new.to_h }

    it { is_expected.to eq(match_all: {}) }
  end

  describe '.parse' do
    context 'with no query' do
      subject { described_class.parse('') }

      it { is_expected.to eq(match_all: {}) }
    end

    context 'with only the query text' do
      subject { described_class.parse('foo') }

      it { is_expected.to eq(match: { _all: 'foo' }) }
    end

    context 'with options' do
      subject { described_class.parse('foo', options) }

      context 'with `:on` option' do
        context 'with a single field' do
          let(:options) { { on: :name } }

          it { is_expected.to eq(match: { name: 'foo' }) }
        end

        context 'with multiple fields on `:on` option' do
          let(:options) { { on: %i(name description) } }

          it { is_expected.to eq(multi_match: { query: 'foo', fields: %i(name description) }) }
        end

        context 'with a composed name on `:on` option' do
          let(:options) { { on: 'company.name' } }

          it { is_expected.to eq(match: { 'company.name': 'foo' }) }
        end
      end

      context 'with `:only/:except` option' do
        context 'with only `:only` option' do
          context 'with a single clause' do
            let(:options) { { only: { status: :published } } }

            it 'returns a filtered query with a `term` filter' do
              is_expected.to eq(
                filtered: {
                  query: { match: { _all: 'foo' } },
                  filter: { term: { status: :published } }
                }
              )
            end
          end

          context 'with multiple clauses' do
            let(:options) { { only: { status: :published, company_id: 1 } } }

            it 'returns a filtered query with an `and` filter' do
              is_expected.to eq(
                filtered: {
                  query: { match: { _all: 'foo' } },
                  filter: {
                    and: [
                      { term: { status: :published } },
                      term: { company_id: 1 }
                    ]
                  }
                }
              )
            end
          end

          context 'with a nested attribute' do
            let(:options) { { only: { company: { id: 1 } } } }

            it 'returns a filtered query with a `term` filter on dotted notation' do
              is_expected.to eq(
                filtered: {
                  query: { match: { _all: 'foo' } },
                  filter: { term: { 'company.id': 1 } }
                }
              )
            end
          end

          context 'with multiple values' do
            let(:options) { { only: { status: %i(published rejected) } } }

            it 'returns a filtered query with a `terms` filter' do
              is_expected.to eq(
                filtered: {
                  query: { match: { _all: 'foo' } },
                  filter: { terms: { status: %i(published rejected) } }
                }
              )
            end
          end
        end

        context 'with only `:except` option' do
          context 'with a single clause' do
            let(:options) { { except: { status: :published } } }

            it 'returns a filtered query with a `not` filter wrapping a `term` filter' do
              is_expected.to eq(
                filtered: {
                  query: { match: { _all: 'foo' } },
                  filter: { not: { term: { status: :published } } }
                }
              )
            end
          end

          context 'with multiple clauses' do
            let(:options) { { except: { status: :published, company_id: 1 } } }

            it 'returns a filtered query with a `not` filter wrapping an `and` filter' do
              is_expected.to eq(
                filtered: {
                  query: { match: { _all: 'foo' } },
                  filter: {
                    and: [
                      { not: { term: { status: :published } } },
                      not: { term: { company_id: 1 } }
                    ]
                  }
                }
              )
            end
          end

          context 'with a nested attribute' do
            let(:options) { { except: { company: { id: 1 } } } }

            it 'returns a filtered query with a `not` filter wrapping a `term` filter on dotted notation' do
              is_expected.to eq(
                filtered: {
                  query: { match: { _all: 'foo' } },
                  filter: { not: { term: { 'company.id': 1 } } }
                }
              )
            end
          end

          context 'with multiple values' do
            let(:options) { { except: { status: %i(published rejected) } } }

            it 'returns a filtered query with `not` filter wrapping a `terms` filter' do
              is_expected.to eq(
                filtered: {
                  query: { match: { _all: 'foo' } },
                  filter: { not: { terms: { status: %i(published rejected) } } }
                }
              )
            end
          end
        end

        context 'with both options' do
          let(:options) { { only: { status: :published }, except: { company_id: 1 } } }

          it 'returns a filtered query combining the filters' do
            is_expected.to eq(
              filtered: {
                query: { match: { _all: 'foo' } },
                filter: {
                  and: [
                    { term: { status: :published } },
                    not: { term: { company_id: 1 } }
                  ]
                }
              }
            )
          end
        end
      end

      context 'with `:includes` option' do
        let(:options) { { includes: ['bar', on: :description] } }

        it 'returns a filtered query with query filter' do
          is_expected.to eq(
            filtered: {
              query: { match: { _all: 'foo' } },
              filter: {
                query: { match: { description: 'bar' } }
              }
            }
          )
        end

        it 'calls `.parse` for the includes option' do
          allow(described_class).to receive(:parse).with('foo', options).and_call_original
          expect(described_class).to receive(:parse).with('bar', on: :description).and_call_original
          subject
        end
      end

      context 'with `:boost_by` option' do
        let(:options) { { boost_by: :contents_count } }

        it 'returns a function score query with a `field_value_factor` function' do
          is_expected.to eq(
            function_score: {
              query: { match: { _all: 'foo' } },
              field_value_factor: {
                field: :contents_count,
                modifier: :ln2p
              }
            }
          )
        end
      end

      context 'with `:boost_function` option' do
        context 'without params' do
          let(:options) { { boost_function: "_score * doc['users_count'].value" } }

          it 'returns a function score query with a `script_score` function' do
            is_expected.to eq(
              function_score: {
                query: { match: { _all: 'foo' } },
                script_score: {
                  script: "_score * doc['users_count'].value"
                }
              }
            )
          end
        end

        context 'with params' do
          let(:options) { { boost_function: ['_score * test_param', params: { test_param: 1 }] } }

          it 'returns a function score query with a `script_score` function and params' do
            is_expected.to eq(
              function_score: {
                query: { match: { _all: 'foo' } },
                script_score: {
                  script: '_score * test_param',
                  params: {
                    test_param: 1
                  }
                }
              }
            )
          end
        end
      end

      context 'with `:boost_where` option' do
        context 'with a regular attribute' do
          let(:options) { { boost_where: { status: :published } } }

          it 'returns a function score query with a `boost_factor` filtered function' do
            is_expected.to eq(
              function_score: {
                query: { match: { _all: 'foo' } },
                functions: [
                  {
                    filter: { term: { status: :published } },
                    boost_factor: 1000
                  }
                ]
              }
            )
          end
        end

        context 'with a multiple attributes' do
          let(:options) { { boost_where: { status: :published, company_id: 1 } } }

          it 'returns a function score query with a `boost_factor` filtered function' do
            is_expected.to eq(
              function_score: {
                query: { match: { _all: 'foo' } },
                functions: [
                  {
                    filter: {
                      and: [
                        { term: { status: :published } },
                        term: { company_id: 1 }
                      ]
                    },
                    boost_factor: 1000
                  }
                ]
              }
            )
          end
        end

        context 'with a nested attribute' do
          let(:options) { { boost_where: { company: { id: 1 } } } }

          it 'returns a function score query with a `boost_factor` filtered function' do
            is_expected.to eq(
              function_score: {
                query: { match: { _all: 'foo' } },
                functions: [
                  {
                    filter: { term: { 'company.id': 1 } },
                    boost_factor: 1000
                  }
                ]
              }
            )
          end
        end

        context 'with multiple values' do
          let(:options) { { boost_where: { status: %i(published rejected) } } }

          it 'returns a function score query with a `boost_factor` filtered function' do
            is_expected.to eq(
              function_score: {
                query: { match: { _all: 'foo' } },
                functions: [
                  {
                    filter: { terms: { status: %i(published rejected) } },
                    boost_factor: 1000
                  }
                ]
              }
            )
          end
        end
      end
    end
  end
end
