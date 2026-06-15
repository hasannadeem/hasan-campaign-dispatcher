class ApplicationJob < ActiveJob::Base
  # Both jobs are idempotent (the recipient claim and counter updates are guarded
  # by a row lock), so these retries are safe:
  #   - a transient deadlock under concurrent counter writes backs off and retries
  #     instead of surfacing as a failed send;
  #   - a job whose record was deleted in the meantime is dropped rather than
  #     retried all the way to the dead set.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5

  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveJob::DeserializationError
end
