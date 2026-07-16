import { logout } from "@/lib/auth/actions";

export function LogoutButton() {
  return (
    <form action={logout}>
      <button type="submit" className="text-sm font-semibold text-red-700 hover:text-red-800">
        Log out
      </button>
    </form>
  );
}
