module Jobs
  class DirectoryRefreshDaily < Jobs::Scheduled
    every 1.hour

    def execute(args)
      DirectoryItem.refresh_period!(:daily)
      
      CurrentDirectoryItem.refresh_period!(:first_quarterly)
    end
  end
end
