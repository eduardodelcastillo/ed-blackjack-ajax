require 'rubygems'
require 'sinatra'
require 'date'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'lana' 

helpers do 
  def calculate_total(cards)
    total = 0
    ace_count = 0
    cards.each do |c|
      if (1..10).include?(c.last.to_i)
        total += c.last.to_i
      elsif %w(J Q K).include?(c.last)
        total += 10
      elsif c.last == 'A'
        total += 11
        ace_count += 1
      end
    end
    #correct for aces
    ace_count.times do 
      total -= 10 if total > 21
    end
    total
  end

  def visualize_card(card)
    suit = card[0]
    value = card[1]
    if %w(J Q K A).include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end
    "<img src = '/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def compare_results
    player_total = calculate_total(session[:player_cards])
    dealer_total = calculate_total(session[:dealer_cards])
    if dealer_total > 21
      @win = "Dealer busted at #{dealer_total}. #{session[:player_name]} wins!"
      session[:player_score] += 1  
      session[:player_pot] += session[:player_bet]
    elsif player_total == dealer_total
      @info = "It's a tie!"
    elsif player_total > dealer_total
      @win = "Dealer has #{dealer_total} while #{session[:player_name]} has #{player_total}. #{session[:player_name]} wins!"
      session[:player_score] += 1  
      session[:player_pot] += session[:player_bet]     
    elsif player_total < dealer_total
      @error = "Dealer has #{dealer_total} while #{session[:player_name]} has #{player_total}. #{session[:player_name]} loses!"
      session[:dealer_score] += 1  
      session[:player_pot] -= session[:player_bet]
      check_pot
    end
    @game_over = true
  end    

  def check_pot
    if session[:player_pot].to_i <= 0
      @broke = true
    end
  end 

  def set_records
    if session[:player_pot].to_i > session[:max_pot].to_i
      session[:max_pot] = session[:player_pot]
      session[:high_player] = session[:player_name]
      session[:date] = Time.now.strftime("%d/%m/%Y %H:%M")     
    end
  end
end

before do
  @hit_or_stay_buttons = false
  @dealer_turn = false
  @dealer_hit_button = false
  @dealer_second_card_button = false
  @game_over = false  
  @broke = false  
end

get '/' do
  if session[:player_name]
    redirect '/bet'
  else
    redirect '/get_name'
  end
end

get '/get_name' do
  session[:player_pot] = 500
  if session[:max_pot].nil?
    session[:max_pot] = 0
  end
  erb :get_name
end

post '/get_name' do 
  if params[:player_name].empty?
    @error = "Name is required."
    halt erb(:get_name)
  end
  session[:player_name] = params[:player_name]  
  session[:player_score] = 0
  session[:dealer_score] = 0
  session[:counter] = 0
  redirect '/bet'
end

get '/bet' do
  erb :bet
end

post '/bet' do
  if params[:bet_amount].empty?
    @error = "Please make a bet."
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_pot]
    @error = "You can't bet more than you have."
    halt erb(:bet)
  elsif params[:bet_amount].to_i.to_s != params[:bet_amount] || params[:bet_amount].to_i <= 0
    @error = "Please enter a valid amount."
    halt erb(:bet)
  else
    session[:player_bet] = params[:bet_amount].to_i
    session[:counter] += 1
    redirect '/game'
  end
end

get '/game' do
  @hit_or_stay_buttons = true
  cards = %w(2 3 4 5 6 7 8 9 10 J Q K A)
  suits = %w(spades clubs hearts diamonds)
  deck = suits.product(cards)
  # Using 4 deck of cards for the game
  session[:deck] = deck * 4
  session[:deck].shuffle!  
  session[:player_cards] = []
  session[:dealer_cards] = [] 
  2.times do 
    session[:player_cards] << session[:deck].pop
    session[:dealer_cards] << session[:deck].pop
  end 
  player_total = calculate_total(session[:player_cards])
  if player_total == 21
    @hit_or_stay_buttons = false
    @win = "#{session[:player_name]} hits blackjack! #{session[:player_name]} wins!"
    @game_over = true
    session[:player_score] += 1
    session[:player_pot] += session[:player_bet]
  else 
    @hit_or_stay_buttons = true
  end

  erb :game
end

post '/game/player/hit' do
  @hit_or_stay_buttons = true
  session[:player_cards] << session[:deck].pop
  if calculate_total(session[:player_cards]) > 21
    @error = "Sorry, #{session[:player_name]} busted at #{calculate_total(session[:player_cards])}!"
    @hit_or_stay_buttons = false
    @game_over = true
    session[:dealer_score] += 1 
    session[:player_pot] -= session[:player_bet]  
    check_pot 
  elsif calculate_total(session[:player_cards]) == 21
    @win = "#{session[:player_name]} got 21."
    @hit_or_stay_buttons = false
    redirect '/game/dealer'
  end

  erb :game, layout: false
end

post '/game/player/stay' do 
  @hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  @dealer_turn = true
  dealer_total = calculate_total(session[:dealer_cards])
  #check for blackjack
  if session[:dealer_cards].length == 2 && dealer_total == 21
    @error = "Dealer hits blackjack. #{session[:player_name]} loses!"
    @game_over = true
    session[:dealer_score] += 1
    session[:player_pot] -= session[:player_bet]    
    check_pot    
  elsif dealer_total >= 17
    @dealer_hit_button = false
    compare_results    
  else
    @dealer_hit_button = true
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do   
  session[:dealer_cards] << session[:deck].pop

  redirect '/game/dealer'
end

post '/game/play_again_yes' do
  redirect '/bet'
end

post '/game/play_again_no' do
  @hit_or_stay_buttons = false
  set_records
  erb :bye
end

get '/bye' do 
  set_records
  erb :bye
end