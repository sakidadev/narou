# frozen_string_literal: true

#
# Copyright 2013 whiteleaf. All rights reserved.
#

module Device::Aozorazip
  PHYSICAL_SUPPORT = false
  VOLUME_NAME = nil
  DOCUMENTS_PATH_LIST = nil
  EBOOK_FILE_EXT = ".zip"
  NAME = "AozoraZip"
  DISPLAY_NAME = "青空文庫Zip"

  RELATED_VARIABLES = {
    "default.enable_half_indent_bracket" => false
  }

  #
  # i文庫用にテキストと挿絵ファイルをzipアーカイブ化する
  #
  def hook_convert_txt_to_ebook_file(&original_func)
    return false if @options["no-zip"]
    
    # 分割ファイルはスルー
    return false if @converted_txt_path =~ /_(\d+)\.txt$/
    delete_files = []
    
    
    
    require "zip"
    # SJISで出力
    #Zip.unicode_names = true
    # TODO: テキストファイル変換時もsettingを取れるようにする
    setting = {}
    if @novel_data
      setting = NovelSetting.load(@novel_data["id"], @options["ignore-force"], @options["ignore-default"])
    end
    dirpath = File.dirname(@converted_txt_path)
    translate_illust_chuki_to_img_tag
    zipfile_path = @converted_txt_path.sub(/.txt$/, @device.ebook_file_ext)
    File.delete(zipfile_path) if File.exist?(zipfile_path)
    Zip::File.open(zipfile_path, Zip::File::CREATE) do |zip|
      # SJISで出力
      zip.add(File.basename(@converted_txt_path).encode('cp932'), @converted_txt_path)
      # 挿絵
      if setting["enable_illust"]
        illust_dirpath = File.join(dirpath, Illustration::ILLUST_DIR)
        if File.exist?(illust_dirpath)
          Dir.glob(File.join(illust_dirpath, "*")) do |img_path|
            # SJISで出力
            zip.add(File.join(Illustration::ILLUST_DIR, File.basename(img_path)).encode('cp932'), img_path)
          end
        end
      end
      # 表紙画像
      cover_name = NovelConverter.get_cover_filename(dirpath)
      if cover_name
        zip.add(cover_name, File.join(dirpath, cover_name))
      end
      
      # 分割ファイルを追加
      Dir.glob(File.join(dirpath, "*.txt")) do |txt_path|
          next if File.basename(txt_path) !~ /_(\d+)\.txt$/
          
          
          # 挿絵注記をimgタグに変換する
          data = File.read(txt_path, encoding: Encoding::UTF_8)
          data.gsub!(/［＃挿絵（(.+?)）入る］/, "<img src=\"\\1\">")
          File.write(txt_path, data)
          
          num = File.basename(txt_path).scan(/_(\d+)\.txt$/)
          #puts File.basename(txt_path).sub(/_(\d+)\.txt$/, "_%03d.txt" % num[0])
          
          zip.add(File.basename(txt_path).sub(/_(\d+)\.txt$/, "_%04d.txt" % num[0]).encode('cp932'), txt_path)
          
          delete_files.push(txt_path)
          #puts txt_path
      end
      
      zip.close()
    end
    
    #puts @options["zip_timestamp_modified"]
    #puts caller.join("\n")
    #puts $_general_lastup
  
    puts File.basename(zipfile_path) + " を出力しました"
    puts "<bold><green>#{@device.display_name}用ファイルを出力しました</green></bold>".termcolor
    
    if Narou.economy?("cleanup_temp") && @argument_target_type == :novel
      # 作業用ファイルを削除
      FileUtils.rm_f(@converted_txt_path)
      if delete_files.length then
         FileUtils.rm_f(delete_files)
      end
    end
    
    #File.utime(@options["zip_timestamp_modified"], @options["zip_timestamp_modified"], zipfile_path)

    
    
    zipfile_path
  end

  #
  # 挿絵注記をimgタグに変換する
  #
  def translate_illust_chuki_to_img_tag
    data = File.read(@converted_txt_path, encoding: Encoding::UTF_8)
    data.gsub!(/［＃挿絵（(.+?)）入る］/, "<img src=\"\\1\">")
    File.write(@converted_txt_path, data)
  end
end
