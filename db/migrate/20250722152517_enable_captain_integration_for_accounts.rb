class EnableCaptainIntegrationForAccounts < ActiveRecord::Migration[7.1]
  def up
    Account.find_each do |account|
      account.enable_features!('captain_integration')
    end
  end
end
