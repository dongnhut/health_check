# Copyright (c) 2010-2013 Ian Heggie, released under the MIT license.
# See MIT-LICENSE for details.

module HealthCheck
  class HealthCheckController < ActionController::Base

    layout false if self.respond_to? :layout

    def index
      last_modified = Time.now.utc
      max_age = HealthCheck.max_age
      if max_age > 1
        last_modified = Time.at((last_modified.to_f / max_age).floor * max_age).utc
      end
      if stale?(:last_modified => last_modified)
        checks = params[:checks] || 'standard'
        begin
          errors = HealthCheck::Utils.process_checks(checks)
        rescue Exception => e
          errors = e.message.blank? ? e.class.to_s : e.message.to_s
        end     
        response.headers['Cache-control'] = 'private, no-cache, must-revalidate' + (max_age > 0 ? ", max-age=#{max_age}" : '')
        if errors.blank?
          obj = { :healthy => true, :message => HealthCheck.success }
          respond_to do |format|
            format.html { render :text => HealthCheck.success, :content_type => 'text/plain' }
            format.json { render :json => obj }
            format.xml { render :xml => obj }
            format.any { render :text => HealthCheck.success, :content_type => 'text/plain' }
          end
        else
          msg = "health_check failed: #{errors}"
          obj = { :healthy => false, :message => msg }
          respond_to do |format|
            format.html { render :text => msg, :status => HealthCheck.http_status_for_error_text, :content_type => 'text/plain'  }
            format.json { render :json => obj, :status => HealthCheck.http_status_for_error_object}
            format.xml { render :xml => obj, :status => HealthCheck.http_status_for_error_object }
            format.any { render :text => msg, :status => HealthCheck.http_status_for_error_text, :content_type => 'text/plain'  }
          end
          # Log a single line as some uptime checkers only record that it failed, not the text returned
          if logger
            logger.info msg
          end
        end
      end
    end


    protected

    # turn cookies for CSRF off
    def protect_against_forgery?
      false
    end

  end
end
