import React, { useState, useEffect } from 'react';

function App() {
  const [searchTerm, setSearchTerm] = useState('');
  const [user, setUser] = useState(null);

  // VULNERABILITY: Storing Secrets in LocalStorage
  useEffect(() => {
    const token = localStorage.getItem('auth_token');
    if (token) setUser({ name: 'Admin User' });
  }, []);

  const handleLogin = () => {
    localStorage.setItem('auth_token', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
    setUser({ name: 'Admin User' });
  };

  // VULNERABILITY: XSS via dangerouslySetInnerHTML
  const ProductCard = ({ product }) => (
    <div className="card">
      <h3>{product.name}</h3>
      <div dangerouslySetInnerHTML={{ __html: product.description }} />
    </div>
  );

  const maliciousProduct = {
    name: "Free Gift!",
    description: "Click here <img src=x onerror=alert('Hacked!') />"
  };

  return (
    <div className="App">
      <h1>LeakyBucket Shop</h1>
      {!user ? <button onClick={handleLogin}>Login</button> : <p>Welcome Admin</p>}
      <input type="text" onChange={(e) => setSearchTerm(e.target.value)} />
      <p>Searching for: {searchTerm}</p>
      <ProductCard product={maliciousProduct} />
    </div>
  );
}

export default App;