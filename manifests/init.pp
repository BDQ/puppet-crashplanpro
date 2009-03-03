# /etc/puppet/modules/crashplan_client/manifests

class crashplan::client {
	case $version {
    "": { $version = "2008-12-22"
      warning("version not set, using default $version")
    }
  }

	case $target_dir {
    "": { $target_dir = "/usr/local/crashplan"
      warning("target_dir not set, using default $target_dir")
    }		
	}
	
	file { "/usr/local/src": ensure => directory }
	file { target_dir:, path => $target_dir, ensure => directory}
	file { target_dir_java:, path => "$target_dir/java", ensure => directory, require => File[target_dir]}
	
	file { "/usr/local/src/CrashPlanPRO_$version.cpi":
      source => "puppet://puppet/crashplan_client/CrashPlanPRO_$version.cpi",
      alias  => "crashplan-client-source-cpi",
			require => File["/usr/local/src"]
  }
	
	exec { "get-jre-64":
		command => "wget http://download.crashplan.com/linuxjvm/jre1.5.x64.cpi -O jre1.5.cpi",
		cwd => "/usr/local/src",
		creates => "/usr/local/src/jre1.5.cpi",
		onlyif => "facter architecture | grep x86_64",
		timeout => "-1",
		notify => Exec["extract-crashplan-client-jre"]
	}
	 
	exec { "get-jre-32":
		command => "wget http://download.crashplan.com/linuxjvm/jre1.5.i586.cpi -O jre1.5.cpi",
		cwd => "/usr/local/src",
		creates => "/usr/local/src/jre1.5.cpi",		
		onlyif => "facter architecture | grep i",
		timeout => "-1",
		notify => Exec["extract-crashplan-client-jre"]
	}
	
	file { "crashplan-client-initscript":
		name => '/etc/init.d/crashplan',
		owner => root,
		group => root,
		mode => 655,
		content => template("crashplan_client/crashplan.erb")
	}
	
	exec { "extract-crashplan-client-jre":
      command => "cat /usr/local/src/jre1.5.cpi | gzip -d -c - | cpio -i --no-preserve-owner",
			cwd => "$target_dir/java",
	    path => ["/usr/bin", "/usr/sbin", "/bin"],
			creates => "$target_dir/java/bin",
      require => File[target_dir_java]
  }
	
  exec { "extract-crashplan-client-source":
      command => "cat /usr/local/src/CrashPlanPRO_$version.cpi | gzip -d -c - | cpio -i --no-preserve-owner",
			cwd => $target_dir,
	    path => ["/usr/bin", "/usr/sbin", "/bin"],
			creates => "$target_dir/bin",
      require => File[crashplan-client-source-cpi , target_dir]
  }

	file { "crashplan-client-engine":
		name => "$target_dir/bin/CrashPlanEngine",
		owner => root,
		group => root,
		mode => 655,
		content => template("crashplan_client/CrashPlanEngine"),
		require => Exec["extract-crashplan-client-source"]
	}

	file { "crashplan-client-installvars":
		name => "$target_dir/install.vars",
		owner => root,
		group => root,
		mode => 644,
		content => template("crashplan_client/install.vars.erb"),
		require => Exec["extract-crashplan-client-source"]
	}

	service { "crashplan":
			enable => true,
			ensure => "running",
			require => [ 
				File["crashplan-client-initscript", "crashplan-client-engine", "crashplan-client-installvars"], 
				Exec["extract-crashplan-client-jre"],
				Exec["extract-crashplan-client-source"] ]
	}
}


