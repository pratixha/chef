#
# Author:: Tim Smith (<tsmith@chef.io>)
# Copyright:: 2020, Chef Software Inc.
# Copyright:: 2017-2020, Microsoft Corporation
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "spec_helper"

describe Chef::Resource::Plist do
  let(:resource) { Chef::Resource::Plist.new("fakey_fakerton") }

  it "sets the default action as :set" do
    expect(resource.action).to eql([:set])
  end

  it "path is the name property" do
    expect(resource.path).to eql("fakey_fakerton")
  end

  describe "#plistbuddy_command" do
    context "Adding a value to a plist" do
      it "the bool arguments contain the data type" do
        expect(resource.plistbuddy_command(:add, "FooEntry", "path/to/file.plist", true)).to eq "/usr/libexec/PlistBuddy -c 'Add :\"FooEntry\" bool' \"path/to/file.plist\""
      end

      it "the add command only adds the data type" do
        expect(resource.plistbuddy_command(:add, "QuuxEntry", "path/to/file.plist", 50)).to eq "/usr/libexec/PlistBuddy -c 'Add :\"QuuxEntry\" integer' \"path/to/file.plist\""
      end

      it "the delete command is formatted properly" do
        expect(resource.plistbuddy_command(:delete, "BarEntry", "path/to/file.plist")).to eq "/usr/libexec/PlistBuddy -c 'Delete :\"BarEntry\"' \"path/to/file.plist\""
      end

      it "the set command is formatted properly" do
        expect(resource.plistbuddy_command(:set, "BazEntry", "path/to/file.plist", false)).to eq "/usr/libexec/PlistBuddy -c 'Set :\"BazEntry\" false' \"path/to/file.plist\""
      end

      it "the print command is formatted properly" do
        expect(resource.plistbuddy_command(:print, "QuxEntry", "path/to/file.plist")).to eq "/usr/libexec/PlistBuddy -c 'Print :\"QuxEntry\"' \"path/to/file.plist\""
      end

      it "the command to set a dictionary data type is formatted properly" do
        expect(resource.plistbuddy_command(:set, "AppleFirstWeekday", "path/to/file.plist", gregorian: 4)).to eq "/usr/libexec/PlistBuddy -c 'Set :\"AppleFirstWeekday\":gregorian 4' \"path/to/file.plist\""
      end
    end

    context "The value provided contains spaces" do
      it "returns the value properly formatted with double quotes" do
        expect(resource.plistbuddy_command(:print, "Foo Bar Baz", "path/to/file.plist")).to eq "/usr/libexec/PlistBuddy -c 'Print :\"Foo Bar Baz\"' \"path/to/file.plist\""
      end
    end

    context "The value to be added contains spaces" do
      it "returns the value properly formatted with double quotes" do
        expect(resource.plistbuddy_command(:add, "Foo Bar Baz", "path/to/file.plist", true)).to eq "/usr/libexec/PlistBuddy -c 'Add :\"Foo Bar Baz\" bool' \"path/to/file.plist\""
      end
    end

    context "The plist itself contains spaces" do
      it "returns the value properly formatted with double quotes" do
        expect(resource.plistbuddy_command(:print, "Foo Bar Baz", "Library/Preferences/com.parallels.Parallels Desktop.plist")).to eq "/usr/libexec/PlistBuddy -c 'Print :\"Foo Bar Baz\"' \"Library/Preferences/com.parallels.Parallels Desktop.plist\""
      end
    end
  end

  describe "#convert_to_data_type_from_string" do
    context "When the type is boolean and given a 1 or 0" do
      it "returns true if entry is 1" do
        expect(resource.convert_to_data_type_from_string("boolean", "1")).to eq true
      end

      it "returns false if entry is 0" do
        expect(resource.convert_to_data_type_from_string("boolean", "0")).to eq false
      end
    end

    context "When the type is integer and the value is 1" do
      it "returns the value as an integer" do
        expect(resource.convert_to_data_type_from_string("integer", "1")).to eq 1
      end
    end

    context "When the type is integer and the value is 0" do
      it "returns the value as an integer" do
        expect(resource.convert_to_data_type_from_string("integer", "0")).to eq 0
      end
    end

    context "When the type is integer and the value is 950224" do
      it "returns the correct value as an integer" do
        expect(resource.convert_to_data_type_from_string("integer", "950224")).to eq 950224
      end
    end

    context "When the type is string and the value is also a string" do
      it "returns the correct value still as a string" do
        expect(resource.convert_to_data_type_from_string("string", "corge")).to eq "corge"
      end
    end

    context "When the type is float and the value is 3.14159265359" do
      it "returns the correct value as a float" do
        expect(resource.convert_to_data_type_from_string("float", "3.14159265359")).to eq 3.14159265359
      end
    end

    context "When the type nor the value is given" do
      it "returns an empty string" do
        expect(resource.convert_to_data_type_from_string(nil, "")).to eq ""
      end
    end
  end

  describe "#type_to_commandline_string" do
    context "When given a certain data type" do
      it "returns the required boolean entry type as a string" do
        expect(resource.type_to_commandline_string(true)).to eq "bool"
      end

      it "returns the required array entry type as a string" do
        expect(resource.type_to_commandline_string(%w{foo bar})).to eq "array"
      end

      it "returns the required dictionary entry type as a string" do
        expect(resource.type_to_commandline_string("baz" => "qux")).to eq "dict"
      end

      it "returns the required string entry type as a string" do
        expect(resource.type_to_commandline_string("quux")).to eq "string"
      end

      it "returns the required integer entry type as a string" do
        expect(resource.type_to_commandline_string(1)).to eq "integer"
      end

      it "returns the required float entry type as a string" do
        expect(resource.type_to_commandline_string(1.0)).to eq "float"
      end
    end
  end
end
