%global app_root %{_datadir}/%{name}
%define gem_name sugarjar
%define version 0.0.9
%define release 1

Name: rubygem-%{gem_name}
Summary: A git/github helper utility
Version: %{version}
Release: %{release}%{?dist}
Group: Development
License: ASL 2.0
Source0: https://rubygems.org/downloads/sugarjar-%{version}.gem
URL: http://www.github.com/jaymzh/sugarjar
BuildRequires: rubygems-devel
BuildArch: noarch

%description
Sugarjar is a utility to help making working with git
and GitHub easier. In particular it has a lot of features
to make rebase-based and squash-based workflows simpler.

%prep
%setup -q -n  %{gem_name}-%{version}

%build
gem build ../%{gem_name}-%{version}.gemspec
%gem_install

%install
mkdir -p %{buildroot}%{gem_dir}
cp -a ./%{gem_dir}/* %{buildroot}%{gem_dir}/

mkdir -p %{buildroot}%{_bindir}
cp -a ./%{_bindir}/* %{buildroot}%{_bindir}
find %{buildroot}%{gem_instdir}/bin -type f | xargs chmod a+x

%clean
rm -rf $RPM_BUILD_ROOT

%files
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
