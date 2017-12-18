def time(method = 'none')
    return Time.at(Time.now + TRIAL_SUSPEND_DELAY).ctime if method == 'TrialController'
    return Time.now.ctime
end

def fmt_time(sec)
    sec = sec.to_i
    days = (sec / 86400).to_i
    sec -= days * 86400
    hours = (sec / 3600.0).to_i
    sec -= hours * 3600
    minutes = (sec / 60.0).to_i
    return "#{days}d:#{hours}h:#{minutes}m:#{sec % 60}s"
end
