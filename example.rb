#! /usr/bin/env ruby

# 田村ゆかりのいたずら黒うさぎを取得するサンプル

require 'lib/crawler.rb'

class MyCrawler < Crawler

  # 各種設定
  def collect_input_data
    # ニコニコ動画のアカウント設定のファイル
    @account_setting_file = 'account.yaml'
    # 読み込む公開リスト
    @input_feed_url = 'http://www.nicovideo.jp/mylist/5204620?rss=2.0'
    # 出力するフィードのパス
    @output_feed_path = '~/public_html/podcast/yukari.xml'
    # enclosureを出力するディレクトリのパス
    @output_file_path = '~/public_html/podcast/enclosure'
    # 外から見た上のディレクトリのパス
    @output_file_url = 'http://hogehoge.com/~user/podcast/enclosure'
    # 入力されるenclosure(ニコニコ動画の場合はflv)
    @input_file_type = 'flv'
    # 出力するenclosure(mp3など)
    @output_file_type = 'mp3'
    # ffmpegのオプション(これを変えると動画も出せるはず)
    @ffmpeg_option = '-acodec copy'
  end

  # フィードの整形
  def hook_publish_feed
    @output_feed.channel.title = 'いたずら黒うさぎ(251回〜)'
    @output_feed.items.each do |item|
      item.title.gsub!(/(田村ゆかりの)?いたずら黒うさぎ/,'')
      item.title.gsub!('回','回 ')
      item.title.gsub!(/「|」|（|）|（|）/, '')
      item.title.gsub!(/( |　)+/,' ')
      item.title.strip!
    end
  end
end

MyCrawler.new.run
