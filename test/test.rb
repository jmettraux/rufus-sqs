
#
# testing the sqs with yaml messages
#

require 'test/unit'

require 'yaml'
require 'base64'

require 'rufus/sqs'


class SqsTest < Test::Unit::TestCase

  #def setup
  #end

  #def teardown
  #end

  def test_usage

    qs = Rufus::SQS::QueueService.new

    qs.create_queue "mytestqueue"

    msg = "hello SQS world !"

    msg_id = qs.put_message "mytestqueue", msg

    sleep 1

    msgs = qs.get_messages "mytestqueue"

    assert_equal 1, msgs.size
    assert_equal msg, msgs[0].message_body

    qs.delete_queue "mytestqueue"
  end

  def test_0

    hash = {
      :red => :color,
      :count => "twelve",
      "fish" => "sakana",
      :llen => 4,
      :list => [ 0, 1, 2, 3, 4, :fizz ]
    }

    qs = Rufus::SQS::QueueService.new

    qs.create_queue(:yamltest)

    puts "created queue 'yamltest'"

    msg = YAML.dump(hash)
    msg = Base64.encode64(msg)

    puts "message size is #{msg.size.to_f / 1024.0} K"

    msg_id = qs.put_message(:yamltest, msg)

    puts "sent hash as message, msg_id is #{msg_id}"

    sleep 1

    msg = qs.get_message(:yamltest, msg_id)

    puts "got message back"

    msg = Base64.decode64(msg.message_body)
    msg = YAML.load(msg)

    pp msg

    assert_equal msg, hash

    count = qs.flush_queue(:yamltest)

    puts "flushed #{count} messages from queue 'yamltest'"

    qs.delete_queue(:yamltest)
  end
end

