#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

# マイリストを動画形式でPodcastにするサンプル

require 'lib/crawler.rb'

class MyCrawler < Crawler

  # 各種設定
  def collect_input_data
    # ニコニコ動画のアカウント設定のファイル
    @account_setting_file = 'account.yaml'
    # 読み込む公開リスト
    @input_feed_url = 'http://www.nicovideo.jp/mylist/7766687?rss=2.0'
    # 出力するフィードのパス
    @output_feed_path = '~/public_html/podcast/for_touch.xml'
    # enclosureを出力するディレクトリのパス
    @output_file_path = '~/public_html/podcast/enclosure'
    # 外から見た上のディレクトリのパス
    @output_file_url = 'http://hogehoge.com/~user/podcast/enclosure'
    # 入力されるenclosure(ニコニコ動画の場合はflv)
    @input_file_type = 'flv'
    # 出力するenclosure(動画の場合はmp4)
    @output_file_type = 'mp4'
    # ffmpegのオプション
    @ffmpeg_option = '-vcodec mpeg4 -r 23.976 -b 600k -acodec libfaac -ac 2 -ar 44100 -ab 128k'
  end
end

# newで設定を読んでrunで実行
MyCrawler.new.run
