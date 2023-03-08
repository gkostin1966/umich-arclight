class CreateFindingaids < ActiveRecord::Migration[5.2]
  def change
    create_table :findingaids do |t|
      t.string :filename
      t.binary :content
      t.string :md5sum
      t.string :sha1sum
      t.string :corpname
      t.string :reponame
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
