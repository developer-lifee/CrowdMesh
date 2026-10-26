require "xcodeproj"

root = File.expand_path(File.dirname(__FILE__))
project_path = File.join(root, "CrowdMesh.xcodeproj")
project = Xcodeproj::Project.new(project_path)

app_target = project.new_target(:application, "CrowdMesh", :ios, "17.0")
app_target.add_system_framework("SwiftUI")
app_target.add_system_framework("MultipeerConnectivity")
app_target.add_system_framework("CoreBluetooth")

app_target.build_configurations.each do |config|
  config.build_settings["DEVELOPMENT_TEAM"] = "PHVD7727SU"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["CODE_SIGN_IDENTITY"] = "Apple Development"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.estebanavila.CrowdMesh"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  config.build_settings["SDKROOT"] = "iphoneos"
  config.build_settings["SUPPORTED_PLATFORMS"] = "iphonesimulator iphoneos"
  config.build_settings["TARGETED_DEVICE_FAMILY"] = "1,2"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
  config.build_settings["INFOPLIST_FILE"] = "CrowdMesh-Info.plist"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
  config.build_settings["MARKETING_VERSION"] = "1.0"
end

group = project.main_group.new_group("Sources/CrowdMesh")
Dir[File.join(root, "Sources/CrowdMesh/*")].sort.each do |file|
  next if File.directory?(file)
  group.new_file(file)
end
app_target.add_file_references(group.files)

project.save
puts "Successfully created CrowdMesh.xcodeproj!"
