# tests won't work until dependent packages are available
%bcond_with tests

%global app_root %{_datadir}/%{name}
%define gem_name sugarjar
%define version 0.0.9
%define release 1

%global common_description %{expand:
Sugarjar is a utility to help making working with git
and GitHub easier. In particular it has a lot of features
to make rebase-based and squash-based workflows simpler.}

Name: rubygem-%{gem_name}
Summary: A git/github helper utility
Version: %{version}
Release: %{release}%{?dist}
License: ASL 2.0
URL: http://www.github.com/jaymzh/sugarjar
BuildRequires: rubygems-devel
BuildRequires: rubygem-mixlib-shellout
BuildArch: noarch
Source0: https://rubygems.org/downloads/sugarjar-%{version}.gem
# git clone https://github.com/jaymzh/sugarjar.git
# git checkout v0.0.9
# tar -cf rubygem-sugarjar-0.0.9-specs.tar.gz spec/
Source1: %{name}-%{version}-specs.tar.gz

%description
%{common_description}

%package -n sugarjar
Summary: A git/github helper utility
Requires: hub, git
%description -n sugarjar
%{common_description}

%prep
%setup -q -n %{gem_name}-%{version} -b 1

%build
gem build ../%{gem_name}-%{version}.gemspec
%gem_install

%install
mkdir -p %{buildroot}%{gem_dir}
cp -a ./%{gem_dir}/* %{buildroot}%{gem_dir}/

mkdir -p %{buildroot}%{_bindir}
cp -a ./%{_bindir}/* %{buildroot}%{_bindir}
find %{buildroot}%{gem_instdir}/bin -type f | xargs chmod a+x

%if %{with tests}
%check
pushd .%{gem_instdir}
ln -s %{_builddir}/spec .
rspec spec
popd
%endif

%clean
rm -rf $RPM_BUILD_ROOT

%files -n sugarjar
%dir %{gem_instdir}
%{_bindir}/sj
%{gem_instdir}/bin
%doc %{gem_instdir}/LICENSE
%doc %{gem_instdir}/README.md
%{gem_libdir}
%exclude %{gem_cache}
%exclude %{gem_instdir}/{Gemfile,sugarjar.gemspec}
# We don't have ri/rdoc in our sources
%exclude %{gem_docdir}
%{gem_spec}

%changelog
* Sun Feb 28 2021 Phil Dibowitz <phil@ipom.com> - 0.0.9-1
- Initial package
