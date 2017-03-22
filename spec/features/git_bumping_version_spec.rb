# frozen_string_literal: true
# rubocop:disable Metrics/BlockLength
RSpec.describe 'bumping version' do
  include_context 'shared settings'
  let(:repo) { VersionManager::GitRepository.new(root_dir, options) }
  let(:default_confirmation_func) { ->(_new_version) { true } }

  context 'when repository does not contains any versions' do
    let(:initial_version) { VersionManager::ReleaseVersion.new('1.0.0') }
    it 'retrieves an initial version' do
      repo.init
      retrieve_initial_version_func = ->() { initial_version }

      release_new_version(:major, default_confirmation_func, retrieve_initial_version_func)

      expect(repo).to have_version(initial_version.bump_major)
      expect(repo).to have_tag(initial_version.bump_major)
      expect(repo).to have_branch(release_name(initial_version.bump_major))
    end
  end

  context 'when initial version is presented' do
    let(:initial_version) { VersionManager::ReleaseVersion.new('1.0.0') }
    let(:current_version) { initial_version.bump_major }
    before do
      repo.init
      retrieve_initial_version_func = ->() { initial_version }
      release_new_version(:major, default_confirmation_func, retrieve_initial_version_func)
    end

    context 'when current branch is a master branch' do
      before { repo.checkout_to_master_branch }
      it 'bumped major version' do
        release_new_version(:major)
        expect(repo).to have_version(current_version.bump_major)
        expect(repo).to have_tag(current_version.bump_major)
        expect(repo).to have_branch(release_name(current_version.bump_major))
      end

      it 'bumped minor version' do
        release_new_version(:minor)
        expect(repo).to have_version(current_version.bump_minor)
        expect(repo).to have_tag(current_version.bump_minor)
        expect(repo).to have_branch(release_name(current_version.bump_minor))
      end

      it 'does not bump patch version' do
        expect { release_new_version(:patch) }.to(
          raise_error(VersionManager::ReleaseManager::ForbiddenBranchError)
        )
      end
    end

    context 'when current branch is different from a master branch' do
      it 'does not bump major version' do
        expect { release_new_version(:major) }.to(
          raise_error(VersionManager::ReleaseManager::ForbiddenBranchError)
        )
      end

      it 'does not bump minor version' do
        expect { release_new_version(:minor) }.to(
          raise_error(VersionManager::ReleaseManager::ForbiddenBranchError)
        )
      end

      it 'bumped patch version' do
        release_new_version(:patch)
        expect(repo).to have_version(current_version.bump_patch)
        expect(repo).to have_tag(current_version.bump_patch)
        expect(repo).to have_branch(release_name(current_version.bump_patch))
      end
    end
  end

  context 'when repository is not up to date' do
    let(:initial_version) { VersionManager::ReleaseVersion.new('1.0.0') }
    let(:current_version) { initial_version.bump_major }
    before do
      repo.init
      retrieve_initial_version_func = ->() { initial_version }
      release_new_version(:major, default_confirmation_func, retrieve_initial_version_func)
    end

    %i(major minor patch).each do |version_type|
      it "does not bump #{version_type} version" do
        repo.checkout_to_master_branch
        repo.add_and_commit_changes
        expect { release_new_version(version_type) }.to(
          raise_error(VersionManager::ReleaseManager::BranchIsNotUpToDateError)
        )
      end
    end
  end

  def release_new_version(release_type, confirmation_func = default_confirmation_func, retrieve_init_version_func = nil)
    VersionManager::ActionManager
      .new(options)
      .release_new_version(release_type, confirmation_func, retrieve_init_version_func)
  end

  def release_name(version)
    VersionManager::VCS.branch_name(version, options.dig(:vcs, :options))
  end
end
