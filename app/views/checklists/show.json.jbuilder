json.extract! @checklist, :id, :name, :template_id, :public
json.entries @checklist.entries do |entry|
  json.extract! entry, :id, :content, :position, :user_id
end
