defmodule SocialContentGenerator.Schema do
  @moduledoc """
  Common schema functionality for all schemas.
  Provides soft delete functionality and common query helpers.
  """

  defmacro __using__(_) do
    quote do
      import Ecto.Query

      def soft_delete(queryable) do
        from(q in queryable, update: [set: [deleted_at: fragment("NOW()")]])
      end

      def not_deleted(queryable) do
        from(q in queryable, where: is_nil(q.deleted_at))
      end

      def deleted(queryable) do
        from(q in queryable, where: not is_nil(q.deleted_at))
      end

      def restore(queryable) do
        from(q in queryable, update: [set: [deleted_at: nil]])
      end
    end
  end
end
