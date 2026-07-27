require_relative '../../lib/sugarjar/commands'
require_relative '../../lib/sugarjar/config'

describe 'Sugarjar::Commands' do
  let(:sj) do
    SugarJar::Commands.new({ 'no_change' => true })
  end

  context '#_modernize' do
    it 'moves host-config defaults from top-level configs' do
      old = {
        'use_forks' => false,
        'feature_prefix' => 'stuff',
      }
      expected = {
        'host_configs' => {
          'default' => old.dup,
        },
      }
      new = sj.send(:_modernize, old)
      expect(new).to eq(expected)
      # explicitly check these too, even though the above should catch it
      expect(new).not_to have_key('use_forks')
      expect(new).not_to have_key('feature_prefix')
    end

    it 'does not overwrite existing bool defaults from old top-level configs' do
      old = {
        'use_forks' => false,
        'feature_prefix' => 'stuff',
        'host_configs' => {
          'default' => {
            'use_forks' => true,
          },
        },

      }
      expected = {
        'host_configs' => {
          'default' => {
            # don't overrite new one
            'use_forks' => true,
            # set one not previously set
            'feature_prefix' => 'stuff',
          },
        },
      }
      new = sj.send(:_modernize, old)
      expect(new).to eq(expected)
    end

    it 'does not overwrite existing str defaults from old top-level configs' do
      old = {
        'use_forks' => false,
        'feature_prefix' => 'stuff',
        'host_configs' => {
          'default' => {
            'feature_prefix' => 'newstuff',
          },
        },

      }
      expected = {
        'host_configs' => {
          'default' => {
            'use_forks' => false,
            # do not overwrite already-set thing
            'feature_prefix' => 'newstuff',
          },
        },
      }
      new = sj.send(:_modernize, old)
      expect(new).to eq(expected)
    end

    it 'moves top-level forge users to their default hosts' do
      old = {
        'github_user' => 'ghuser',
        'gitlab_user' => 'gluser',
      }
      expected = {
        'host_configs' => {
          'default' => {},
          'github.com' => {
            'user' => 'ghuser',
          },
          'gitlab.com' => {
            'user' => 'gluser',
          },
        },
      }
      new = sj.send(:_modernize, old)
      expect(new).to eq(expected)
    end

    it 'does not overwrite exisiting users' do
      old = {
        'github_user' => 'ghuser',
        'gitlab_user' => 'gluser',
        'host_configs' => {
          'github.com' => {
            'user' => 'anotheruser',
          },
        },
      }
      expected = {
        'host_configs' => {
          'default' => {},
          'github.com' => {
            'user' => 'anotheruser',
          },
          'gitlab.com' => {
            'user' => 'gluser',
          },
        },
      }
      new = sj.send(:_modernize, old)
      expect(new).to eq(expected)
    end

    it 'populates default users into non-default hosts with no user' do
      old = {
        'github_user' => 'ghuser',
        'gitlab_user' => 'gluser',
        'host_configs' => {
          'gitlab.company.com' => {
            'use_forks' => true,
          },
          'github.example.com' => {
            'feature_prefix' => 'something/',
          },
          'github.anothercompany.com' => {
            'user' => 'specificuser',
          },
          'gitlab.sample.com' => {
            'user' => 'anotherspecificuser',
          },
        },
      }

      expected = {
        'host_configs' => {
          'default' => {},
          # always populate defaults if not set
          'github.com' => {
            'user' => 'ghuser',
          },
          'gitlab.com' => {
            'user' => 'gluser',
          },
          # these are populated, they weren't set
          'gitlab.company.com' => {
            'use_forks' => true,
            'user' => 'gluser',
          },
          'github.example.com' => {
            'feature_prefix' => 'something/',
            'user' => 'ghuser',
          },
          # these don't get set, they were already set
          'github.anothercompany.com' => {
            'user' => 'specificuser',
          },
          'gitlab.sample.com' => {
            'user' => 'anotherspecificuser',
          },
        },
      }
      new = sj.send(:_modernize, old)
      expect(new).to eq(expected)
    end
  end
end
