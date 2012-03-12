# coding: utf-8

require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'carrierwave'
require 'carrierwave/datamapper'
require 'RMagick'
include Magick
#include CarrierWave::RMagick

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite:./db/page.db')

#конфигурация carrierwave
class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  storage :file
  version :thumb do
    process :resize_to_fill => [100,100]
  end
end

class MyImage
  include DataMapper::Resource
  property :id, Serial
  mount_uploader :image, ImageUploader, type: String

  #include DataMapper::Resource
  #mount_uploader :image, ImageUploader, type: String
  #field :title, type: String
end

class Page
  include DataMapper::Resource

  property :id,               Serial
  property :name,             String
  property :alias,            String
  property :short,            Text
  property :full,             Text
  property :seo_title,        String
  property :seo_keywords,     String
  property :seo_description,  String
  property :created_at,       DateTime
  property :updated_at,       DateTime
end

DataMapper.finalize

#Для изменения таблиц
#DataMapper.auto_migrate!

#Sinatra configuration
set :public_directory, './public'

#helpers
helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Cms's restricted area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.username && @auth.credentials == ['admin', 'password']
  end
end

before '/admin/*' do
  protected!
  @default_layout = :admin
end

#create
get '/admin/create' do
  erb :create_form
end

get '/admin/edit/:id' do
  # fill form
  @page = Page.get(params[:id])
  erb :edit_form
end

post '/admin/edit/:id' do
  @page = Page.get(params[:id])
  params.delete 'submit'
  params.delete 'id'
  params.delete 'splat'
  params.delete 'captures'
  params[:updated_at] = Time.now
  @page.attributes = params
  @page.save
  redirect '/admin/pages'
end

post '/tests/upload.php' do
	@image = MyImage.new
  @image.image = params[:file] #загрузка изображения
  @image.save

	#content_type 'image/jpg'
  #img = File.read(@image.image.current_path)
  #img.format = 'jpg'
  #img.to_blob
  #для версии 5 возвращается только путь
  #return @image.image.url

  #content_type @image.image.content_type #'image/jpg'
  #@image.image.read()

  #img = Magick::Image.read(@image.image.current_path)[0]
  #img = File.open(@image.image.current_path)
  #send_file @image.image.current_path, :filename => @image.image.filename, :type => 'image/jpeg'
  #content_type 'image/jpg'
  #img.read
  #img.format = 'jpg'
  #img.to_blob
	"<img src=#{@image.image.url} />"
end

get '/tests/images.json' do
	content = '['
	MyImage.all.each do |img|
		content += '{"thumb": "'
		content += img.image.thumb.url
		content += '", "image": "'
		content += img.image.url
		content += '"},'
	end
	content = content[0,content.length-1]
	content += ']'
	content
end

post '/admin/create' do
  params.delete 'submit'
  params[:updated_at] = params[:created_at] = Time.now
  @page = Page.create(params)
  redirect '/admin/pages'
end

get '/admin/pages' do
  @pages = Page.all
  erb :pages
end

#deleting
get '/admin/delete/:id' do
  Page.get(params[:id]).destroy
  redirect '/admin/pages'
end

get '/' do
  @page = Page.first(:alias => 'mainpage')
  @pages = Page.all(:alias.not => 'mainpage')
  erb :page
end

get '/:alias.html' do
  @page = Page.first(:alias => params[:alias])
  not_found 'Страница не найдена' if @page.nil?
  @pages = Page.all(:alias.not => 'mainpage')
  erb :page
end


not_found do
  erb :'404', {:layout => false}
end
