export default function Header({ name }) {
  return (
    <header className="header">
      <h1>Billing</h1>
      <p className="welcome">{'Welcome back, ' + name}</p>
    </header>
  );
}
