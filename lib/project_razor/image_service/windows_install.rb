require "fileutils"
require "digest/sha2"
require "erb"

module ProjectRazor
  module ImageService
    # Image construct for generic Operating System install ISOs
    class WindowsInstall < ProjectRazor::ImageService::Base

      attr_accessor :windows_version
      attr_accessor :windows_language
      attr_accessor :windows_architecture
      attr_accessor :windows_servicepack
      attr_accessor :windows_images

      IMAGEX_COMMAND = (Process::uid == 0 ? "imagex" : "sudo imagex")

      def command?(name)
        `which #{name}`
        $?.success?
      end

      def set_win_path(path)
        @_win_svc_path = path[0,path.rindex("/")] + "/win"
      end

      def wimboot_path
        @_win_svc_path  + "/wimboot"
      end

      def httpdiskdriver64_path
        @_win_svc_path  + "/httpdisk_amd64.sys"
      end

      def config
        get_data.config
      end

      def httpdisk_path
        @_win_svc_path  + "/httpdisk_i386.exe"
      end

      def api_svc_uri
        "http://#{config.image_svc_host}:#{config.api_port}/razor/api"
      end

      def image_svc_uri
        "http://#{config.image_svc_host}:#{config.image_svc_port}/razor/image/windows"
      end

      def readerb(erbfilename)
	filepath = File.join(File.dirname(__FILE__), "windows/#{erbfilename}.erb")
	ERB.new(File.read(filepath)).result(binding)
      end

      def httpdiskdriver_path
        @_win_svc_path  + "/httpdisk_i386.sys"
      end

      def httpdisk64_path
        @_win_svc_path  + "/httpdisk_amd64.exe"
      end


      def initialize(hash)
        super(hash)
        @description = "Windows Install"
        @path_prefix = "windows"
        @hidden = false
        from_hash(hash) unless hash == nil
      end

      def add(src_image_path, image_svc_path, extra)
        set_win_path(image_svc_path)
        begin
          unless command?(IMAGEX_COMMAND)
            logger.error "missing imagex command: #{IMAGEX_COMMAND}"
            return [false, "Missing imagex command. Install it from http://sourceforge.net/projects/wimlib/"]
          end

          unless File.exists?(wimboot_path)
            logger.error "missing wimboot: #{wimboot_path}"
            return [false, "Missing wimboot. Download it from http://git.ipxe.org/releases/wimboot/wimboot-latest.zip and copy wimboot to #{wimboot_path}"]
          end

          resp = super(src_image_path, image_svc_path, extra)
          if resp[0]
            unless verify(image_svc_path)
              logger.error "Missing metadatassss"
              return [false, "Missing metadata"]
            end

            return resp
          else
            resp
          end
        rescue => e
          logger.error e.message
          return [false, e.message]
        end
      end

      def copyto(srcfile,dstfile)
	if File.exists?(srcfile)
          logger.debug "Copy file from #{srcfile} to #{dstfile}!"
          puts "Copy file from #{srcfile} to #{dstfile}!"
          FileUtils.cp_r(srcfile, dstfile ) unless File.exists?(dstfile)
	  return true
	else
 	  return false	
	end
      end

      def posttasks(image_svc_path)
        unless is_mounted?(mount_path_installwim)
	  unless mountwim(installwim_path,mount_path_installwim,false)
            logger.error "Could not mount #{installwim_path} on #{mount_path_installwim}"
            return false
          end
	end
	
        unless mountwim(bootwim_path,mount_path_bootwim,true)
          logger.error "Could not mount #{bootwim_path} on #{mount_path_bootwim}"
          return false
        end

        if @windows_architecture == "x86_64"
          unless File.exists?(httpdiskdriver64_path)
            logger.error "#{httpdiskdriver64_path} drivers not found"
            return false
          end

          unless File.exists?(httpdisk64_path)
            logger.error "#{httpdisk64_path}  not found"
            return false
          end
        else
          unless File.exists?(httpdiskdriver_path)
            logger.error "#{httpdiskdriver_path} drivers not found"
            return false
          end

          unless File.exists?(httpdisk_path)
            logger.error "#{httpdisk_path} not found"
            return false
          end
        end

        begin
	  unless copyto("#{mount_path_installwim}#{scsys32_path}","#{mount_path_bootwim}#{scsys32_path}")
            logger.error "Copy failed"
	    return false
	  end
	  
	  unless  copyto("#{mount_path_installwim}#{scmuisys32_path}","#{mount_path_bootwim}#{scmuisys32_path}")
	    logger.error "Copy failed"
	    return false
	  end

	  unless copyto(httpdiskdriver64_path,"#{mount_path_bootwim}/Windows/System32/drivers/httpdisk.sys")
	   logger.error "Copy failed"
	   return false
	  end 

	  unless copyto(httpdisk64_path,"#{mount_path_bootwim}/Windows/System32/httpdisk.exe")
	    logger.error "Copy failed"
	    return false
	  end

	  unless copyto(wimboot_path,"#{image_path}/wimboot") 
	   logger.error "Copy failed"
	   return false
	  end

	  File.open("#{mount_path_bootwim}/Windows/System32/Winpeshl.ini", 'w') { |file| file.write(readerb("Winpeshl")) }
	  File.open("#{mount_path_bootwim}/Windows/System32/startnet.cmd", 'w') { |file| file.write(readerb("startnet")) }
	  File.open("#{mount_path_bootwim}/Windows/System32/razorconf.vbs", 'w') { |file| file.write(readerb("configurevbs")) }
	  umountwim(mount_path_installwim,false)
	  umountwim(mount_path_bootwim,true)
          return true
        rescue => e
          logger.error e.message
          return false
        end

      end

      def verify(image_svc_path)
	unless super(image_svc_path)
          logger.error "File structure is invalid"
	  return false
        end

        unless File.exists?(bootmgr_path)
          logger.error "missing bootmgr: #{bootmgr_path}"
          return false
        end

        unless File.exists?(bcd_path)
          logger.error "missing bcd: #{bcd_path}"
          return false
        end

        unless File.exists?(bootsdi_path)
          logger.error "missing sdi: #{bootsdi_path}"
          return false
        end

        unless File.exists?(bootwim_path)
          logger.error "missing boot.wim: #{bootsdi_path}"
          return false
        end

        unless File.exists?(installwim_path)
          logger.error "missing install.wim: #{bootsdi_path}"
          return false
        end

        unless command?(IMAGEX_COMMAND)
          logger.error "missing imagex command: #{IMAGEX_COMMAND}"
          return false
        end
        begin
	  names = Hash.new
          wiminstallinfo =  `#{IMAGEX_COMMAND} info #{installwim_path} 2> /dev/null`
          if $? == 0
	    name,index = nil
            wiminstallinfo.each_line { |line|
              spl = line.gsub(/\s+/, ' ').split(":")
              case true
		when spl[0] == "Index"
		  index = spl[1].strip
                when spl[0] == "Name"
                  name = spl[1].strip
                when spl[0] == "Build"
                  @windows_version =  spl[1].strip
                when spl[0] == "Architecture"
                  @windows_architecture = spl[1].strip
                when spl[0] == "Default Language"
                  @windows_language =  spl[1].strip
              end
              if name != nil && index != nil
                names[index] =  name  
              end

            }
          end

	  if names != nil 
	    @windows_images = names
	  end
	  names.each {|key, value| puts "#{key} is #{value}" }

          if @windows_version == nil
            logger.error "Windows version is nil"
            return false
          end

          if @windows_architecture == nil
            logger.error "Windows architecture is nil"
            return false
          end

          if @windows_language == nil
            logger.error "Windows language is nil"
            return false
          end

          unless posttasks(image_svc_path)
            logger.error "Posttasks failed"
            return false
          end


          true

        rescue => e
          logger.debug e
          false
        end
      end

      def mountwim(src_wim_path,mnt_path,rw)
	mw = "mountrw"
	if rw == false
	  mw = "mount"
	end
	puts "try to mount #{src_wim_path} to #{mnt_path}"
        FileUtils.mkpath(mnt_path) unless File.directory?(mnt_path)
	`#{IMAGEX_COMMAND} #{mw} #{src_wim_path} 2 #{mnt_path} 2> /dev/null`
        if $? == 0 or $? == 5888
          logger.debug "wim mounted: #{src_wim_path} on #{mnt_path}"
          true
        else
	  puts $?
          logger.debug "could not mount wim: #{src_wim_path} on #{mnt_path}"
          false
        end
      end

     def umountwim(mnt_path,commit)
	comstr = ""
        if commit == true
	  comstr = "--check --commit"
	end	
	`#{IMAGEX_COMMAND} unmount #{mnt_path} #{comstr} 2> /dev/null`
        if $? == 0
          logger.debug "wim unmounted: #{mnt_path}"
	  remove_dir_completely mnt_path
          true
        else
          logger.debug "could not unmount wim: #{mnt_path}"
          false
        end
      end

      def remove_dir_completely(path)
        if File.directory?(path)
          FileUtils.rm_r(path, :force => true)
        else
          true
        end
      end

      def mount_path_bootwim
        "#{$temp_path}/#{@uuid}-bootwim"
      end

      def mount_path_installwim
        "#{$temp_path}/#{@uuid}-installwim"
      end

      def bootmgr_path
        image_path + "/bootmgr"
      end

      def bcd_path
        image_path + "/boot/bcd"
      end

      def bootsdi_path
        image_path + "/boot/boot.sdi"
      end

      def bootwim_path
        image_path + "/sources/boot.wim"
      end

      def installwim_path
        image_path + "/sources/install.wim"
      end
      
      def scsys32_path
	"/Windows/System32/sc.exe"
      end

      def scmuisys32_path
        "/Windows/System32/en-US/sc.exe.mui"
      end


      def print_image_info(image_svc_path)
        super(image_svc_path)
        print "\tVersion: "
        print "#{@windows_version}  \n".green
        print "\tArchitecture: "
        print "#{@windows_architecture}  \n".green
        print "\tDefault Language: "
        print "#{@windows_language}  \n".green
	print "\tImages: "
	print "#{@windows_images}  \n".green
      end

      def print_item_header
        super.push "Version","Architecture","Default Language","Images"
      end

      def print_item
	imgs = nil
	if @windows_images != nil
	  @windows_images.each { |key,value| imgs = "#{imgs}(Index: #{key} Name: #{value}) "   }
	end
        super.push @windows_version,@windows_architecture,@windows_language,imgs
      end

    end
  end
end
