import React, { useState, useEffect } from 'react';
import './App.css'; // Import the new styles

function App() {
  const [searchTerm, setSearchTerm] = useState('');
  const [user, setUser] = useState(null);

  // VULNERABILITY: Storing Secrets in LocalStorage
  useEffect(() => {
    const token = localStorage.getItem('auth_token');
    if (token) {
      // Mock fetching user profile
      setUser({ name: 'Admin User', email: 'admin@leakybucket.com' }); 
    }
  }, []);

  const handleLogin = () => {
    // Simulating an insecure login
    localStorage.setItem('auth_token', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
    setUser({ name: 'Admin User', email: 'admin@leakybucket.com' });
  };

  const handleLogout = () => {
    localStorage.removeItem('auth_token');
    setUser(null);
  };

  // Mock Products Data
  const products = [
    {
      id: 1,
      name: "Premium Bucket",
      price: "$29.99",
      image: "https://via.placeholder.com/300x300?text=Premium+Bucket",
      description: "Our flagship bucket. Guaranteed to hold water... mostly."
    },
    {
      id: 2,
      name: "Industrial Hose",
      price: "$49.99",
      image: "https://via.placeholder.com/300x300?text=Hose",
      description: "High pressure, low safety standards."
    },
    {
      id: 3,
      name: "Duct Tape",
      price: "$5.99",
      image: "https://via.placeholder.com/300x300?text=Tape",
      description: "Fixes everything, including security holes."
    },
    {
      id: 999,
      // VULNERABILITY: XSS Payload in content
      name: "Free Gift! (Click Me)",
      price: "FREE",
      image: "https://via.placeholder.com/300x300/ff0000/ffffff?text=FREE+GIFT",
      description: "Congratulations! You won! <img src=x onerror=alert('XSS_ATTACK_SUCCESSFUL_STEALING_LOCALSTORAGE:'+localStorage.getItem('auth_token')) /> Click for details."
    }
  ];

  // Filter products based on search
  const filteredProducts = products.filter(p => 
    p.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="app-container">
      {/* --- NAVIGATION BAR --- */}
      <nav className="navbar">
        <div className="nav-brand">🛒 LeakyBucket</div>
        <div className="nav-search">
          <input 
            type="text" 
            placeholder="Search for products..." 
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)} 
          />
        </div>
        <div className="nav-auth">
          {!user ? (
            <button className="btn-primary" onClick={handleLogin}>Login</button>
          ) : (
            <div className="user-profile">
              <span>Welcome, {user.name}</span>
              <button className="btn-secondary" onClick={handleLogout}>Logout</button>
            </div>
          )}
        </div>
      </nav>

      {/* --- HERO SECTION --- */}
      <header className="hero">
        <div className="hero-content">
          <h1>Summer Sale Is Live!</h1>
          <p>Get 50% off on all vulnerable dependencies. Shop now before we patch.</p>
          <button className="btn-large">Shop Now</button>
        </div>
      </header>

      {/* --- MAIN CONTENT --- */}
      <main className="main-content">
        <h2>Featured Products</h2>
        
        {searchTerm && <p className="search-result">Searching for: <strong>{searchTerm}</strong></p>}

        <div className="product-grid">
          {filteredProducts.map(product => (
            <div key={product.id} className="product-card">
              <img src={product.image} alt={product.name} className="product-image" />
              <div className="product-details">
                <h3>{product.name}</h3>
                <p className="price">{product.price}</p>
                
                {/* VULNERABILITY: XSS via dangerouslySetInnerHTML */}
                <div 
                  className="description"
                  dangerouslySetInnerHTML={{ __html: product.description }} 
                />
                
                <button className="btn-add-cart">Add to Cart</button>
              </div>
            </div>
          ))}
        </div>
      </main>

      {/* --- FOOTER --- */}
      <footer className="footer">
        <p>&copy; 2025 LeakyBucket Shop. All Security Rights Reserved (None).</p>
      </footer>
    </div>
  );
}

export default App;