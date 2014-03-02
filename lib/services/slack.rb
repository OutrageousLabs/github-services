class Service::Slack < Service
  string :token, :channel, :restrict_to_branch
  boolean :notify, :quiet_fork, :quiet_watch, :quiet_comments, :quiet_wiki
  white_list :channel, :restrict_to_branch

  default_events :commit_comment, :download, :fork, :fork_apply, :gollum,
    :issues, :issue_comment, :member, :public, :pull_request, :pull_request_review_comment,
    :push, :watch

  def receive_event
    # make sure we have what we need
    raise_config_error "Missing 'token'" if data['token'].to_s.empty?
    raise_config_error "Missing 'channel'" if data['channel'].to_s.empty?

    # push events can be restricted to certain branches
    if event.to_s == 'push'
      branch = payload['ref'].split('/').last
      branch_restriction = data['restrict_to_branch'].to_s

      # check the branch restriction is poplulated and branch is not included
      if branch_restriction.length > 0 && branch_restriction.index(branch) == nil
        return
      end
    end

    # ignore forks and watches if boolean is set
    return if event.to_s =~ /fork/ && data['quiet_fork']
    return if event.to_s =~ /watch/ && data['quiet_watch']
    return if event.to_s =~ /comment/ && data['quiet_comments']
    return if event.to_s =~ /gollum/ && data['quiet_wiki']

    # payload can be posted to multiple channels as long as each channel
    # is separated by ','
    channels = data['channel'].to_s.split(",")
    channels.collect!(&:strip)
    channels.each do |channel|
      params = {
        :payload => generate_json({
          :channel => channel,
          :username => "GitHub",
          :icon_url => "", # TODO: Ask Slack employee for this support
          :text => payload
        })
      }

      res = http_post "https://envoy.slack.com/services/hooks/incoming-webhook?token=#{data['token']}", params
      if res.status < 200 || res.status > 299
        raise_config_error
      end
    end
  end
end
