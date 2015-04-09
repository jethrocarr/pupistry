require 'rubygems'

module Pupistry
  # Pupistry::Bootstrap

  class Bootstrap
    attr_accessor :template_dir

    def initalize
      template_dir = "dir"
    end
    
    def self.templates_list
      # glob all the templates
      puts "Template"
    end


  end
end

# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
