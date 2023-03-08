class CreateSlugmaps < ActiveRecord::Migration[5.2]
  def change
    create_table :slugmaps do |t|
      t.string :corpname
      t.string :reponame
      t.string :reposlug

      t.timestamps
    end
  end
end
