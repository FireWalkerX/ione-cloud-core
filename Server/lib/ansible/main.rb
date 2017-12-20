########################################################
#          Функция запуска ansible-скриптов            #
########################################################

ANSIBLE_HOST = CONF['AnsibleServer']['host']
ANSIBLE_HOST_PORT = CONF['AnsibleServer']['port']
ANSIBLE_HOST_USER = CONF['AnsibleServer']['user']
require "#{CONF['AnsibleServer']['data-getters-url']}"
require 'net/ssh'
require 'net/sftp'

class WHMHandler
    def AnsibleControllerNew(params)
        host, playbooks = params['host'], params['services']
        LOG params.out, 'DEBUG'
        return if params['out'] == true
        ip, err = host.split(':').first, ""
        Thread.new do
            playbooks.each do |service, playbook|
                installid = Time.now.to_i.to_s(16).crypt(service[0..3])
                LOG "#{service} should be installed on #{ip}, installation ID is: #{installid}", "AnsibleController"
                begin
                    LOG 'Connecting to Ansible', 'DEBUG'            
                    err = "Error while connecting to Ansible-server"
                    Net::SSH.start(ANSIBLE_HOST, ANSIBLE_HOST_USER, :port => ANSIBLE_HOST_PORT) do | ssh |
                        err = "Error while creating temporary playbook file occurred"
                        File.open("/tmp/#{installid}.yml", 'w') { |file| file.write(playbook.gsub('{{group}}', installid)) }
                        err = "Error while uploading playbook occurred"
                        ssh.sftp.upload!("/tmp/#{installid}.yml", "/tmp/#{installid}.yml")
                        err = "Error while creating temporary ansible-inventory file occurred"
                        File.open("/tmp/#{installid}.ini", 'w') { |file| file.write("[#{installid}]\n#{host}\n") }
                        err = "Error while uploading ansible-inventory occurred"
                        ssh.sftp.upload!("/tmp/#{installid}.ini", "/tmp/#{installid}.ini")
                        LOG 'PB and hosts have been generated', 'DEBUG'
                        err = "Error while executing playbook occured"
                        LOG 'Executing PB', 'DEBUG'
                        $pbexec = ssh.exec!("ansible-playbook /tmp/#{installid}.yml -i /tmp/#{installid}.ini").split(/\n/)
                        LOG 'PB has been Executed', 'DEBUG'
                        def status(regexp)
                            return $pbexec.last[regexp].split(/=/).last.to_i
                        end
                        LOG 'Creating log-ticket', 'DEBUG'
                        WHM.new.LogtoTicket(
                            subject: "#{ip}: #{service.capitalize} install",                    
                            message: "
                            IP: #{ip}
                                Service for install: #{service.capitalize}
                                Log: \n    #{$pbexec.join("\n    ")}",
                                method: __method__.to_s,
                                priority: "#{(status(/failed=(\d*)/) | status(/unreachable=(\d*)/) == 0) ? 'Low' : 'High'}",
                        )
                        LOG "#{service} installed on #{ip}", "AnsibleController"
                        LOG 'Wiping hosts and pb files', 'DEBUG'
                        ssh.sftp.remove!("/tmp/#{installid}.ini")
                        File.delete("/tmp/#{installid}.ini")
                        ssh.sftp.remove!("/tmp/#{installid}.yml")
                        File.delete("/tmp/#{installid}.yml")
                    end
                rescue => e
                    LOG "An Error occured, while installing #{service} on #{ip}: #{err}, Code: #{e.message}", "AnsibleController"
                    WHM.new.LogtoTicket(
                        subject: "#{ip}: #{service.capitalize} install",                    
                        message: "
                        IP: #{ip}
                        Service for install: #{service.capitalize}
                        Error: Method-inside error
                        Log: #{err}, code: #{e.message} --- #{e} -- #{e.class}",
                        method: __method__.to_s,
                        priority: 'High'
                    )
                end
            end
            Thread.exit
        end
        return 200
    end
end