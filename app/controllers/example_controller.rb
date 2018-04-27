class ExampleController < ApplicationController
  def redirect
    client = Signet::OAuth2::Client.new(client_options)
    redirect_to client.authorization_uri.to_s
  end

  def callback
    client = Signet::OAuth2::Client.new(client_options)
    client.code = params[:code]

    response = client.fetch_access_token!

    session[:authorization] = response

    redirect_to calendars_url
  end

  def calendars
    client = Signet::OAuth2::Client.new(client_options)
    client.update!(session[:authorization])

    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = client

    @calendar_list = service.list_calendar_lists
  rescue Google::Apis::AuthorizationError
    response = client.refresh!

    session[:authorization] = session[:authorization].merge(response)

    retry
  end

  def new_event

    client = Signet::OAuth2::Client.new(client_options)
    client.update!(session[:authorization])

    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = client

    event = Google::Apis::CalendarV3::Event.new({
      summary: params[events_url][:summary],
      location: '800 Howard St., San Francisco, CA 94103',
      description: params[events_url][:description],
      start: {
        date_time: params[events_url][:start],
        time_zone: 'America/Denver'
      },
      attendees: [
        { email: params[events_url][:attendees] }
      ]
    })
    
    service.insert_event(params[:calendar_id], event)
    redirect_to events_url(calendar_id: params[:calendar_id])
  end

  def events
    client = Signet::OAuth2::Client.new(client_options)
    client.update!(session[:authorization])

    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = client

    @event_list = service.list_events(params[:calendar_id])
    
    gon.push({
      :calendar_id => params[:calendar_id]
    })
  end

  # def new_event
  #   client = Signet::OAuth2::Client.new(client_options)
  #   client.update!(session[:authorization])

  #   service = Google::Apis::CalendarV3::CalendarService.new
  #   service.authorization = client

  #   today = Date.today

  #   event = Google::Apis::CalendarV3::Event.new({
  #     start: Google::Apis::CalendarV3::EventDateTime.new(date: today),
  #     end: Google::Apis::CalendarV3::EventDateTime.new(date: today + 1),
  #     summary: :title
  #   })

  #   service.insert_event(params[:calendar_id], event)

  #   redirect_to events_url(calendar_id: params[:calendar_id])
  # end

  private

  def client_options
    {
      client_id: Rails.application.secrets.google_client_id,
      client_secret: Rails.application.secrets.google_client_secret,
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR,
      redirect_uri: callback_url
    }
  end
end
