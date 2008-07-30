#! /usr/bin/env ruby

require 'rss'
require 'rubygems'
require 'nicovideo'
require 'yaml'

$KCODE = 'UTF8'

class Crawler
  attr_writer :input_feed_url, :output_feed_path, :output_file_path, :output_file_url

  # ここでは設定だけ読んでおく
  def initialize
    collect_input_data
  end

  # クローラーを実行する(fetch feed, download, encode, publish)
  def run
    setup_input_data
    get_feed
    get_input_files
    sync_file_sizes
    get_output_files
    sync_file_sizes
    delete_no_need_files
    generate_feed
    hook_publish_feed
    publish_feed
  end

  # 継承したクラスでここに設定をいろいろ書く
  # writerがあるので、あとから書き換え可
  def collect_input_data
    @input_feed_url = ''
    @output_feed_path = ''
    @output_file_path = ''
    @output_file_url = ''
    @input_file_type = ''
    @output_file_type = ''
    @ffmpeg_option = ''
  end

  # フィードを出力するときに呼ばれる
  # ここでタイトルを見やすいように置換したりする
  def hook_publish_feed
    @output_feed.items.each do |item|
      item.title.strip!
    end
  end
  
  # 設定をあとで使いやすいように整形
  # (相対パスを絶対パスに直したり, )
  def setup_input_data
    @account_setting_file = File.expand_path(@account_setting_file)
    @input_file_type.gsub!(/^\./,'')
    @output_file_type.gsub!(/^\./,'')
    @output_feed_path = File.expand_path(@output_feed_path)
    @output_file_path = File.expand_path(@output_file_path)
    @output_file_url.gsub!(/\/$/,'')
  end

  # フィードを取得してついでに関連情報を格納する
  def get_feed
    @input_feed = download_feed
    @video_keys = get_video_keys
    @file_sizes = get_file_sizes
    @video_titles = get_video_titles
  end

  # フィードをwgetで取ってくる
  def download_feed
    puts "downloading feed(#{@input_feed_url})"
    tmpfile = "/tmp/nicopodcast#{@input_feed_url.scan(/\d+/).first}"
    system "wget -nv -O #{tmpfile} #{@input_feed_url}"
    rss = RSS::Parser.parse(tmpfile)
    File.delete(tmpfile)
    return rss
  end

  # フィードからビデオのidのArrayを得る
  def get_video_keys
    list = []
    @input_feed.items.each do |item|
      if /http\:\/\/www\.nicovideo\.jp\/watch\/(\w+)$/ =~ item.link
        list << $1
      end
    end
    return list
  end

  # フィードからビデオのidとタイトルのHashを得る
  def get_video_titles
    hash = {}
    @input_feed.items.each do |item|
      if /http\:\/\/www\.nicovideo\.jp\/watch\/(\w+)$/ =~ item.link
        hash[$1] = item.title
      end
    end
    return hash
  end

  # ローカルのファイルサイズのHashを@file_sizesに入れる
  def sync_file_sizes
    @file_sizes = get_file_sizes
  end

  # ローカルのinput,outputのファイルサイズのHashを得る
  # hash['sm0000']['flv'] = 4000
  # hash['sm0000']['mp3'] = nil
  # みたいなかんじになる
  def get_file_sizes
    hash = {}
    @video_keys.each do |key|
      hash[key] = {}
      [@input_file_type, @output_file_type].each do |type|
        hash[key][type] = File.size?(output_file_fullpath(key,type))
      end
    end
    return hash
  end

  # 出力ファイルのフルパスを得る
  # key: 'sm00000'とか
  # type: 'mp3'とか
  def output_file_fullpath(key,type)
    return @output_file_path + '/' + key + '.' + type
  end

  # 出力ファイルのURLを得る
  # key: 'sm00000'とか
  # type: 'mp3'とか
  def output_file_fullurl(key,type)
    return @output_file_url + '/' + key + '.' + type
  end

  # ダウンロードすべき動画を調べてダウンロードする
  # 例えば、flvもmp3もないとき、ダウンロードするべき
  def get_input_files
    keys = @file_sizes.delete_if { |key,value|
      value[@input_file_type] or value[@output_file_type]
    }.keys
    if keys.empty? 
      puts "no need to download."
      return
    end

    download(keys)

    return
  end

  # 指定された動画たちをダウンロードする
  # gem nicovideoのサンプル(nv_download)を一部コピー
  # http://rubyforge.org/projects/nicovideo/
  def download(video_ids)
    puts "download: #{video_ids.join(', ')}"
    
    account = YAML.load_file(@account_setting_file)
    mail = account['mail']
    password = account['password']

    nv = Nicovideo.new(mail, password)
    nv.login
    video_ids.each do |video_id|
      nv.watch(video_id) do |v|
        puts "id: #{video_id}"
        puts "downloading #{@video_titles[video_id]}(#{video_id})"
        filepath = output_file_fullpath(video_id,@input_file_type)

        begin
          File.open(filepath, "wb") {|f| f.write v.flv }
        rescue => err
          p err
          puts "deleting file"
          File.delete(filepath)
          puts "sleep 3 seconds"
        else
          puts "...done"
        end
        sleep 3 if video_ids.size > 1
      end
    end

    return
  end

  # エンコードすべき動画を調べてエンコードする
  # (エンコードとは、flvをmp3とかにする作業)
  # 例えば、flvがあって、mp3がないとき、エンコードするべき
  def get_output_files
    keys = @file_sizes.select { |key,value|
      value[@input_file_type] and not value[@output_file_type]
    }.map{ |t| t.first }

    if keys.empty? 
      puts "no need to encode."
      return
    end

    encode(keys)
    return
  end

  # ffmpegでinput_fileをoutput_fileにエンコードする
  def encode(video_ids)
    puts "encode: #{video_ids.join(', ')}"
    video_ids.each do |video_id|
      puts "encoding #{video_id}"
      input_path = output_file_fullpath(video_id,@input_file_type)
      output_path = output_file_fullpath(video_id,@output_file_type)
      system "ffmpeg -i #{input_path} #{@ffmpeg_option} #{output_path}"
      puts "...done"
    end
    return
  end

  # input_fileもouput_fileもあるときinput_fileを削除する
  def delete_no_need_files
    keys = @file_sizes.select { |key,value|
      value[@input_file_type] and value[@output_file_type]
    }.map { |t| t.first }

    if keys.empty?
      puts "no need to delete"
      return
    end
    puts "delete: #{keys.join(', ')}"
    keys.each do |key|
      path = output_file_fullpath(key,@input_file_type)
      puts "deleting #{path}"
      File.delete(path)
    end
    return
  end

  # フィードを生成する
  # 新しいフィードを作って、input_feedから要素をコピーして、
  # enclosureをつけたりする
  def generate_feed
    puts "generating feed"
    @output_feed = RSS::Maker.make("2.0") do |maker|
      maker.channel.description = @input_feed.channel.description
      maker.channel.generator = @input_feed.channel.generator
      maker.channel.language = @input_feed.channel.language
      maker.channel.lastBuildDate = @input_feed.channel.lastBuildDate
      maker.channel.link = @input_feed.channel.link
      maker.channel.managingEditor = @input_feed.channel.managingEditor
      maker.channel.pubDate = @input_feed.channel.pubDate
      maker.channel.title = @input_feed.channel.title

      maker.items.do_sort = true

      @input_feed.items.each do |in_item|
        key = in_item.link.scan(/(sm\d+)/).first.to_s
        unless @file_sizes[key][@output_file_type]
          puts "skip #{key}"
          puts "skip #{@video_titles[key]}"
          next
        end
        
        item = maker.items.new_item
        item.description = in_item.description
        item.title = in_item.title
        item.link = in_item.link
        item.pubDate = in_item.pubDate
        item.guid.content = in_item.guid.content
        item.guid.isPermaLink = in_item.guid.isPermaLink
        item.enclosure.url = output_file_fullurl(key,@output_file_type)
        item.enclosure.type = "audio/mpeg"
        item.enclosure.length = @file_sizes[key][@output_file_type]
      end
    end
  end

  # フィードを書き出す
  def publish_feed
    puts "writing feed at #{@output_feed_path}"
    if File.size?(@output_feed_path)
      outfile = File.open(@output_feed_path,'w')
    else
      outfile = File.new(@output_feed_path,'w')
    end
    outfile.puts @output_feed.to_s
    outfile.close
    puts "done"
  end
end
