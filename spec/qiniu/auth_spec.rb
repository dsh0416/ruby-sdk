# -*- encoding: utf-8 -*-
# vim: sw=2 ts=2

require 'spec_helper'
require 'qiniu/auth'
require 'qiniu/storage'
require 'digest/sha1'

module Qiniu
  module Auth
    describe Auth do

      before :all do
        @bucket = 'rubysdk'
      end
      after :all do
      end

      ### 测试私有资源下载
      context ".download_private_file" do
        it "should works" do
          ### 生成Key
          key = 'a_private_file'
          key = make_unique_key_in_bucket(key)
          puts "key=#{key}"

          ### 上传测试文件
          pp = Auth::PutPolicy.new(@bucket, key)
          code, data, raw_headers = Qiniu::Storage.upload_with_put_policy(
            pp,
            __FILE__
          )
          code.should == 200
          puts data.inspect
          puts raw_headers.inspect

          ### 获取下载地址
          code, data = Qiniu::Storage.get(@bucket, key)
          code.should == 200
          puts data.inspect

          url = data['url']

          ### 授权下载地址（不带参数）
          download_url = Qiniu::Auth.authorize_download_url(url)
          puts "download_url=#{download_url}"

          result = RestClient.get(download_url)
          result.code.should == 200
          result.body.should_not be_empty

          ### 授权下载地址（带参数）
          download_url = Qiniu::Auth.authorize_download_url(
            url,
            {
              :fop => 'download/a.m3u8'
            }
          )
          puts "download_url=#{download_url}"

          result = RestClient.get(download_url)
          result.code.should == 200
          result.body.should_not be_empty

          ### 删除文件
          code, data = Qiniu::Storage.delete(@bucket, key)
          code.should == 200
          puts data.inspect
        end
      end
    end

    ### 测试回调签名
    context ".authenticate_callback_request" do
      url = '/test.php'
      body = 'name=xxx&size=1234'
      false.should == Qiniu::Auth.authenticate_callback_request('ABCD', url, body)
      false.should == Qiniu::Auth.authenticate_callback_request(Config.settings[:access_key], url, body)
      false.should == Qiniu::Auth.authenticate_callback_request('QBox ' + Config.settings[:access_key] + ':', url, body)
      false.should == Qiniu::Auth.authenticate_callback_request('QBox ' + Config.settings[:access_key] + ':????', url, body)

      acctoken = Qiniu::Auth.generate_acctoken(url, body)
      auth_str = 'QBox ' + acctoken

      false.should == Qiniu::Auth.authenticate_callback_request(auth_str + '  ', url, body)
      true.should == Qiniu::Auth.authenticate_callback_request(auth_str, url, body)
      true.should == Qiniu::Auth.authenticate_callback_request(acctoken, url, body)
    end
  end # module Auth

  module Exception_Auth
    describe Exception_Auth, :not_set_ak_sk => true do
      ### 测试未设置 ak/sk 的异常抛出情况
      context ".not_set_ak_sk" do
        it "should works" do
          puts Qiniu::Config.instance_variable_get("@settings").inspect

          begin
            uptoken = Qiniu::Auth.generate_uptoken({})
          rescue => e
            e.message.should == "Please set Qiniu's access_key and secret_key before authorize any tokens."
          else
            fail "Not raise any exception."
          end

          begin
            download_url = Qiniu::Auth.authorize_download_url("http://test.qiniudn.com/a_private_file")
          rescue => e
            e.message.should == "Please set Qiniu's access_key and secret_key before authorize any tokens."
          else
            fail "Not raise any exception."
          end

          begin
            acctoken = Qiniu::Auth.generate_acctoken("http://rsf.qbox.me/list")
          rescue => e
            e.message.should == "Please set Qiniu's access_key and secret_key before authorize any tokens."
          else
            fail "Not raise any exception."
          end
        end
      end
    end
  end # module Exception_Auth
end # module Qiniu
