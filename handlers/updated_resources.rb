module SimpleReport
  class UpdatedResources < Chef::Handler
    def report
      Chef::Log.info "Resources updated this run:"
      run_status.updated_resources.each {|r| Chef::Log.info "  #{r.to_s}"}
    end
  end
end
