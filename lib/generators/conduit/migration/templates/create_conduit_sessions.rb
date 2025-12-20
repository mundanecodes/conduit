class CreateConduitSessions < ActiveRecord::Migration[8.0] # this needs fixing to make it dynamic?
  def change
    create_table :conduit_sessions do |t|
      t.string :session_id, null: false, index: {unique: true}
      t.string :msisdn, null: false, index: true
      t.string :service_code
      t.string :final_state
      t.jsonb :data, default: {}
      t.integer :duration_seconds
      t.boolean :completed, default: false
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.timestamps null: false

      t.index [:msisdn, :created_at]
      t.index :created_at
    end
  end
end
