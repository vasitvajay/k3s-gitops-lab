const $ = (selector) => document.querySelector(selector);
const grid = $("#productGrid");
const filters = $("#filters");
const productDialog = $("#productDialog");
const cartDialog = $("#cartDialog");
const cartCount = $("#cartCount");
const toast = $("#toast");
let products = [];
let selectedProduct = null;
let cart = [];
let activeCategory = "all";

const money = (amount) => new Intl.NumberFormat("en-IN", {
  style: "currency", currency: "INR", maximumFractionDigits: 0
}).format(amount);

const imageFor = {
  "aura-headphones": "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=800&q=80",
  "pulse-speaker": "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=crop&w=800&q=80",
  "orbit-watch": "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=800&q=80",
  "arc-lamp": "https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=800&q=80",
  "form-bottle": "https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=800&q=80",
  "studio-buds": "https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?auto=format&fit=crop&w=800&q=80"
};

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.detail || `Request failed (${response.status})`);
  return body;
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove("show"), 2600);
}

function renderProducts(items) {
  if (!items.length) {
    grid.innerHTML = '<div class="loading-card">Nothing here just yet. Try another category.</div>';
    return;
  }
  grid.innerHTML = items.map((p) => `
    <article class="product-card" data-product="${p.id}" tabindex="0" role="button" aria-label="View ${p.name}">
      <div class="product-image" style="--tile:${p.color}">
        ${p.tag ? `<span class="product-tag">${p.tag}</span>` : ""}
        <img loading="lazy" src="${imageFor[p.id]}" alt="${p.name}" onerror="this.style.display='none'">
        <button class="quick-add" data-add="${p.id}" aria-label="Quick add ${p.name}">+</button>
      </div>
      <div class="product-info">
        <div class="product-topline"><span class="product-name">${p.name}</span><span class="product-rating">★ ${p.rating}</span></div>
        <div class="product-category">${p.category}</div>
        <div class="product-price">${money(p.price)}</div>
      </div>
    </article>`).join("");
}

function renderFilters(categories) {
  filters.innerHTML = ["all", ...categories].map((category) =>
    `<button class="filter ${category === activeCategory ? "active" : ""}" data-category="${category}">${category === "all" ? "Everything" : category}</button>`
  ).join("");
}

async function loadProducts(category = activeCategory) {
  activeCategory = category;
  grid.innerHTML = '<div class="loading-card">Finding the good stuff…</div>';
  try {
    const result = await api(`/api/products${category === "all" ? "" : `?category=${encodeURIComponent(category)}`}`);
    renderProducts(result.products);
    filters.querySelectorAll(".filter").forEach((button) =>
      button.classList.toggle("active", button.dataset.category === category)
    );
  } catch (error) {
    grid.innerHTML = `<div class="loading-card">Couldn't load the collection. ${error.message}</div>`;
  }
}

async function openProduct(productId) {
  try {
    // Clicking a product calls GET /api/products/{product_id}.
    const result = await api(`/api/products/${encodeURIComponent(productId)}`);
    selectedProduct = result.product;
    const p = selectedProduct;
    $("#productDetail").innerHTML = `
      <div class="detail-image" style="--tile:${p.color}"><img src="${imageFor[p.id]}" alt="${p.name}" onerror="this.style.display='none'"></div>
      <div class="detail-copy">
        <div class="eyebrow">${p.category.toUpperCase()} · NOVA EDITION</div>
        <h2>${p.name}</h2><div class="product-rating">★ ${p.rating} / 5</div>
        <p>${p.description}</p><div class="detail-price">${money(p.price)}</div>
        <div class="detail-meta">Thoughtfully selected. Ready for everyday.</div>
        <button class="primary-button full-width" id="addDetail">Add to bag <span>↗</span></button>
      </div>`;
    $("#addDetail").addEventListener("click", () => addToCart(p.id));
    productDialog.showModal();
  } catch (error) {
    showToast(error.message);
  }
}

function addToCart(productId) {
  const product = products.find((p) => p.id === productId);
  if (!product) return;
  const existing = cart.find((item) => item.id === productId);
  if (existing) existing.quantity += 1;
  else cart.push({ ...product, quantity: 1 });
  updateCart();
  productDialog.close();
  showToast(`${product.name} added to your bag`);
}

function updateCart() {
  const count = cart.reduce((sum, item) => sum + item.quantity, 0);
  cartCount.textContent = count;
  const content = $("#cartContent");
  if (!cart.length) {
    content.innerHTML = "<p>Your bag is waiting for something good.</p>";
    $("#checkoutButton").disabled = true;
    return;
  }
  content.innerHTML = cart.map((item) => `
    <div class="cart-line"><span>${item.name} × ${item.quantity}<br><small>${money(item.price)} each</small></span>
    <span>${money(item.price * item.quantity)} <button data-remove="${item.id}" aria-label="Remove ${item.name}">×</button></span></div>`
  ).join("") + `<div class="cart-line"><b>Total</b><b>${money(cart.reduce((sum, item) => sum + item.price * item.quantity, 0))}</b></div>`;
  $("#checkoutButton").disabled = false;
}

async function checkout() {
  try {
    const orderResults = [];
    // POST /api/orders is called for each product in the demo bag.
    for (const item of cart) {
      const result = await api("/api/orders", {
        method: "POST",
        body: JSON.stringify({ product_id: item.id, quantity: item.quantity })
      });
      orderResults.push(result);
    }
    const ids = orderResults.map((order) => order.order_id).join(", ");
    cart = [];
    updateCart();
    cartDialog.close();
    showToast(`Demo order confirmed: ${ids}`);
  } catch (error) {
    showToast(`Order failed: ${error.message}`);
  }
}

filters.addEventListener("click", (event) => {
  const button = event.target.closest("[data-category]");
  if (button) loadProducts(button.dataset.category);
});
grid.addEventListener("click", (event) => {
  const addButton = event.target.closest("[data-add]");
  if (addButton) {
    event.stopPropagation();
    addToCart(addButton.dataset.add);
    return;
  }
  const card = event.target.closest("[data-product]");
  if (card) openProduct(card.dataset.product);
});
grid.addEventListener("keydown", (event) => {
  const card = event.target.closest("[data-product]");
  if (card && (event.key === "Enter" || event.key === " ")) {
    event.preventDefault();
    openProduct(card.dataset.product);
  }
});
$("#cartButton").addEventListener("click", () => cartDialog.showModal());
$("#dialogClose").addEventListener("click", () => productDialog.close());
$("#cartClose").addEventListener("click", () => cartDialog.close());
$("#checkoutButton").addEventListener("click", checkout);
$("#cartContent").addEventListener("click", (event) => {
  const button = event.target.closest("[data-remove]");
  if (button) {
    cart = cart.filter((item) => item.id !== button.dataset.remove);
    updateCart();
  }
});
for (const dialog of [productDialog, cartDialog]) {
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });
}

async function start() {
  try {
    const [categoryResult, productResult] = await Promise.all([
      api("/api/categories"),
      api("/api/products")
    ]);
    products = productResult.products;
    renderFilters(categoryResult.categories);
    renderProducts(products);
  } catch (error) {
    grid.innerHTML = `<div class="loading-card">NOVA is taking a moment. ${error.message}</div>`;
  }
}
start();
