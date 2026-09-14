defmodule Toolbox.PackagesTest do
  use Toolbox.DataCase, async: true

  alias Toolbox.Packages

  describe "list_packages_names_not_synced_since/1" do
    test "includes packages whose latest snapshot is older than the given datetime" do
      {:ok, stale_package} = create(:package)
      {:ok, stale_snapshot} = create(:hexpm_snapshot, package_id: stale_package.id)

      one_hour_ago =
        DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:second)

      from(hs in Toolbox.HexpmSnapshot, where: hs.id == ^stale_snapshot.id)
      |> Repo.update_all(set: [inserted_at: one_hour_ago])

      cutoff = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, fresh_package} = create(:package)
      {:ok, _fresh_snapshot} = create(:hexpm_snapshot, package_id: fresh_package.id)

      names = Packages.list_packages_names_not_synced_since(cutoff)

      assert stale_package.name in names
      refute fresh_package.name in names
    end

    test "includes packages with no snapshot at all" do
      {:ok, package} = create(:package)

      names =
        Packages.list_packages_names_not_synced_since(DateTime.utc_now())

      assert package.name in names
    end
  end

  describe "delete_package/1" do
    test "deletes the package along with its hexpm and github snapshots" do
      {:ok, package} = create(:package)
      {:ok, _hexpm_snapshot} = create(:hexpm_snapshot, package_id: package.id)

      {:ok, _github_snapshot} =
        Packages.upsert_github_snapshot(%{package_id: package.id, data: %{}})

      assert {:ok, _deleted} = Packages.delete_package(package)

      assert Packages.get_package_by_name(package.name) == nil

      assert Repo.all(from(hs in Toolbox.HexpmSnapshot, where: hs.package_id == ^package.id)) ==
               []

      assert Repo.all(from(gs in Toolbox.GithubSnapshot, where: gs.package_id == ^package.id)) ==
               []
    end
  end

  describe "create_hexpm_snapshot/1" do
    test "add default if missing downloads" do
      {:ok, snapshot} =
        create(:hexpm_snapshot, data: %{"downloads" => %{}})

      assert snapshot.data["downloads"] == %{"recent" => 0}
    end

    test "does not modify downloads if present" do
      {:ok, snapshot} =
        create(:hexpm_snapshot,
          data: %{"downloads" => %{"all" => 10, "recent" => 5}}
        )

      assert snapshot.data["downloads"] == %{"all" => 10, "recent" => 5}
    end
  end
end
