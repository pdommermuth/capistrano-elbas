require 'elbas'
include Elbas::Logger

namespace :elbas do
  task :ssh do
    include Capistrano::DSL

    info "SSH commands:"
    env.servers.to_a.each.with_index do |server, i|
      info "    #{i + 1}) ssh #{fetch(:user)}@#{server.aws_counterpart.public_ip_address}"
    end
  end

  task :deploy do
    fetch(:aws_autoscale_group_names).each do |aws_autoscale_group_name|
      info "Auto Scaling Group: #{aws_autoscale_group_name}"
      asg = Elbas::AWS::AutoscaleGroup.new aws_autoscale_group_name

      puts "Sleep 2 minutes to allow flushing memory to disk to happen"
      sleep(2.minutes)

      info "Creating AMI from a running instance..."
      ami = Elbas::AWS::AMI.create asg.instances.running.sample
      ami.tag 'ELBAS-Deploy-group', asg.name
      ami.tag 'ELBAS-Deploy-id', env.timestamp.to_i.to_s
      ami.tag 'ELBAS-Deploy-date', Time.now.to_s
      info  "Created AMI: #{ami.id}"

      info "Updating launch template with the new AMI..."
      launch_template = asg.launch_template.update ami
      info "Updated launch template, new default version = #{launch_template.version}"

      # info "Cleaning up old AMIs..."
      # ami.ancestors.each do |ancestor|
      #   info "Deleting old AMI: #{ancestor.id}"
      #   ancestor.delete
      # end

      info "Deployment complete!"
    end
  end
end
