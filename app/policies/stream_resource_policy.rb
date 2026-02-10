class StreamResourcePolicy < ApplicationPolicy
  def show?
    StreamRecordingPolicy.new(token, resource.stream_recording).show?
  end

  def create?
    update?
  end

  def update?
    StreamRecordingPolicy.new(token, resource.stream_recording).update?
  end

  def attach?
    update?
  end
end
