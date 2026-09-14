defmodule Toolbox.Workers.HexpmWorker do
  use Oban.Worker, queue: :hexpm, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{meta: %{"cron" => true}}) do
    sync_started_at = DateTime.utc_now() |> DateTime.truncate(:second)

    Toolbox.Tasks.Hexpm.run()

    sync_started_at
    |> Toolbox.Packages.list_packages_names_not_synced_since()
    |> Enum.map(
      &Toolbox.Workers.HexpmWorker.new(%{"action" => "delete_if_missing", "name" => &1})
    )
    |> Enum.chunk_every(500)
    |> Enum.each(&Oban.insert_all/1)

    :ok
  end

  def perform(%Oban.Job{args: %{"action" => "get_package_owners", "name" => name}}) do
    with {:ok, package} <- get_package_by_name(name),
         {:ok, owners_data} <- get_package_owners(name),
         {:ok, p} <-
           Toolbox.Packages.update_package_owners(package, %{
             hexpm_owners_sync_at: DateTime.utc_now(),
             hexpm_owners: owners_data
           }) do
      Phoenix.PubSub.broadcast(
        Toolbox.PubSub,
        "package_live:#{name}",
        %{
          action: :refresh_owners,
          owners_sync_at: p.hexpm_owners_sync_at,
          owners: p.hexpm_owners
        }
      )

      {:ok, p}
    else
      {:skip, reason} ->
        Logger.warning(reason)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def perform(%Oban.Job{
        args: %{"action" => "get_latest_stable_version", "name" => name, "version" => nil}
      }) do
    Logger.warning("Hexpm package #{name} has no latest stable version, skipping version fetch")

    :ok
  end

  def perform(%Oban.Job{
        args: %{"action" => "get_latest_stable_version", "name" => name, "version" => version}
      }) do
    with {:ok, package} <- get_package_by_name(name),
         {:ok, version_data} <- get_package_version(name, version),
         {:ok, p} <-
           Toolbox.Packages.update_package_latest_stable_version(package, %{
             hexpm_latest_stable_version_data: version_data
           }) do
      Phoenix.PubSub.broadcast(
        Toolbox.PubSub,
        "package_live:#{name}",
        %{
          action: :refresh_latest_stable_version,
          latest_stable_version_data: p.hexpm_latest_stable_version_data
        }
      )

      {:ok, p}
    else
      {:skip, reason} ->
        Logger.warning(reason)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: %{"action" => "delete_if_missing", "name" => name}}) do
    with {:ok, package} <- get_package_by_name(name),
         {:ok, :missing} <- check_package_on_hexpm(name),
         {:ok, _package} <- Toolbox.Packages.delete_package(package) do
      Logger.warning("Deleted package #{name}, no longer available on hexpm")

      :ok
    else
      {:skip, reason} ->
        Logger.warning(reason)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_package_by_name(name) do
    case Toolbox.Packages.get_package_by_name(name) do
      %Toolbox.Package{} = package -> {:ok, package}
      nil -> {:skip, "package #{name} not found"}
    end
  end

  defp get_package_version(name, version) do
    case Toolbox.Hexpm.get_package_version(name, version) do
      {:ok, %{status: 200, body: version_data}} ->
        {:ok, Toolbox.Package.HexpmVersion.build_version_from_api_response(version_data)}

      {:ok, %{status: status}} when status in [400, 404] ->
        {:skip, "Unable to fetch hexpm version for #{name} version #{version}"}

      {:ok, %{status: server_error}} when server_error in 500..599 ->
        {:error,
         "failed to fetch hexpm version #{version} for #{name} with status #{server_error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_package_owners(name) do
    case Toolbox.Hexpm.get_package_owners(name) do
      {:ok, %{status: 200, body: owners_data}} ->
        {:ok, owners_data}

      {:ok, %{status: status}} when status in [400, 404] ->
        {:skip, "Unable to fetch hexpm owners for #{name}"}

      {:ok, %{status: server_error}} when server_error in 500..599 ->
        {:error, "failed to fetch hexpm owners for #{name} with status #{server_error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_package_on_hexpm(name) do
    case Toolbox.Hexpm.get_package(name) do
      {:ok, %{status: 404}} ->
        {:ok, :missing}

      {:ok, %{status: 200}} ->
        {:skip, "package #{name} still exists on hexpm, skipping deletion"}

      {:ok, %{status: server_error}} when server_error in 500..599 ->
        {:error, "failed to check hexpm package #{name} with status #{server_error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
