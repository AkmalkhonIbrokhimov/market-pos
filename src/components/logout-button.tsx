import { logout } from "@/lib/auth/actions";

export function LogoutButton({ label }: { label: string }) {
  return (
    <form action={logout}>
      <button type="submit" className="text-sm font-semibold text-red-700 hover:text-red-800">
        {label}
      </button>
    </form>
  );
}
