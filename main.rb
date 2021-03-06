require 'rss'
require 'rubygems'
require 'sinatra'
require 'sequel'

enable :sessions

#$LOAD_PATH.unshift(File.dirname(__FILE__) + '/vendor/json_pure')
#require 'json/pure'

configure do
   # TIP:  You can get you database information
   #       from ENV['DATABASE_URI'] (see /env route below)
   DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://bookmarks.db')
end

helpers do
   def auth(user, pass)
      ds = DB[:users].filter({:name => user} & {:password => pass})
      (ds.count > 0)
      #stop [ 401, 'Not authorized' ]
   end
   
   def user_name(session)
      user = {}
      if session[:user] == nil
         user[:name] = "anonymous"
         user[:id] = 1
      else
         ds = DB[:users].first(:name => session[:user])
         user[:name] = session[:user]
         user[:id] = ds[:id] 
     end
      user
   end
end

get '/' do
   ds = DB[:bookmarks].left_outer_join(:users, :id => :user_id).order(:id.desc).limit(30)
   #ds.each do |r|
   #   p r
   #end
   erb :bookmarks, :locals => {
      :records => ds,
      :user => user_name(session)
   }
end

get '/login' do
   session.clear
   erb :login
end

post '/login' do
   p params
   if auth(params[:name], params[:password])
      session[:user] = params[:name]
      redirect '/'
   else
      session.clear
      erb :login
   end
end

get '/new' do
   erb :new_bookmark, :locals => {
      :hints => params
   }
end

post '/new' do
   DB[:bookmarks].insert({
      :title => params[:title],
      :url => params[:url],
      :tag => params[:tag],
      :note => params[:note],
      :user_id => user_name(session)[:id]
   })
   redirect '/'
end

get '/rss' do
   bookmarks = DB[:bookmarks].order(:id.desc).limit(30)
   
   rss = RSS::Maker.make("2.0") do |maker|

      maker.channel.about = "http://localhost:9292/"
      maker.channel.title = "kodama"
      maker.channel.description = "New Arrivals for kodama."
      maker.channel.link = "http://localhost:9292/"

      maker.items.do_sort = true
      
      bookmarks.each do |bookmark|
         item = maker.items.new_item
         item.link = bookmark[:url]
         item.title = bookmark[:title]	#TODO escape
         #item.date = m.modified_at
         item.description = bookmark[:notes]	#TODO escape
      end
   end
   rss.to_s
end

get '/env' do
   ENV.inspect
end

get '/users' do
   erb :users, :locals => {
      :records => DB[:users]
   }
end

get '/user/new' do
   erb :new_user
end

post '/user/new' do
   DB[:users].insert({
      :profile => params[:profile],
      :name => params[:name],
      :password => params[:password],
   })
   redirect '/users'
end
