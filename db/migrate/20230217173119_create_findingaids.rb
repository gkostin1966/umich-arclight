class CreateFindingaids < ActiveRecord::Migration[5.2]
  def change
    create_table :findingaids do |t|
      t.string :filename
      t.string :content
      t.integer :size
      t.string :corpname
      t.string :reposlug
      t.string :eadid
      t.string :eadslug
      t.string :eadurl
      t.string :state
      t.string :error

      t.timestamps
    end
  end
end
