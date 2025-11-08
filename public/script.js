// ========================================
// SAHLA DELIVERY - LANDING PAGE SCRIPT
// ========================================

// Navigation
const navbar = document.getElementById('navbar');
const navLinks = document.getElementById('navLinks');
const navLinkElements = document.querySelectorAll('.nav-link');

// Smooth scroll for navigation links
navLinkElements.forEach(link => {
    link.addEventListener('click', (e) => {
        const href = link.getAttribute('href');
        if (href.startsWith('#')) {
            e.preventDefault();
            const targetId = href.substring(1);
            const targetSection = document.getElementById(targetId);
            if (targetSection) {
                const offset = 64; // navbar height
                const targetPosition = targetSection.offsetTop - offset;
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });

            }
        }
    });
});


// Navbar scroll effect
let lastScroll = 0;
window.addEventListener('scroll', () => {
    const currentScroll = window.pageYOffset;

    if (currentScroll > 100) {
        navbar.classList.add('scrolled');
    } else {
        navbar.classList.remove('scrolled');
    }

    // Update active nav link based on scroll position
    updateActiveNavLink();

    lastScroll = currentScroll;
});

// Update active navigation link based on scroll position
function updateActiveNavLink() {
    const sections = document.querySelectorAll('section[id]');
    const scrollPosition = window.pageYOffset + 80;

    sections.forEach(section => {
        const sectionTop = section.offsetTop;
        const sectionHeight = section.offsetHeight;
        const sectionId = section.getAttribute('id');

        if (scrollPosition >= sectionTop && scrollPosition < sectionTop + sectionHeight) {
            navLinkElements.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === `#${sectionId}`) {
                    link.classList.add('active');
                }
            });
        }
    });
}

// Scroll animations
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('aos-animate');
        }
    });
}, observerOptions);

// Observe all elements with data-aos attribute
document.querySelectorAll('[data-aos]').forEach(el => {
    observer.observe(el);
});

// Fetch restaurants from API
async function fetchRestaurants() {
    const restaurantsGrid = document.getElementById('restaurantsGrid');
    if (!restaurantsGrid) return;

    try {
        const response = await fetch('/api/restaurants?limit=3');
        const data = await response.json();

        if (data.success && data.data && data.data.length > 0) {
            restaurantsGrid.innerHTML = '';
            data.data.forEach(restaurant => {
                const restaurantCard = createRestaurantCard(restaurant);
                restaurantsGrid.appendChild(restaurantCard);
            });
        } else {
            // Fallback to placeholder restaurants
            showPlaceholderRestaurants();
        }
    } catch (error) {
        console.error('Error fetching restaurants:', error);
        showPlaceholderRestaurants();
    }
}

// Create restaurant card element
function createRestaurantCard(restaurant) {
    const card = document.createElement('div');
    card.className = 'restaurant-card';
    card.style.opacity = '0';
    card.style.transform = 'translateY(20px)';

    const image = document.createElement('div');
    image.className = 'restaurant-image';

    // Use restaurant image if available
    if (restaurant.logo_url || restaurant.cover_image_url || restaurant.image) {
        const imageUrl = restaurant.cover_image_url || restaurant.logo_url || restaurant.image;
        image.style.backgroundImage = `url(${imageUrl})`;
        image.style.backgroundSize = 'cover';
        image.style.backgroundPosition = 'center';
    } else {
        // Fallback to gradient with emoji
        image.style.background = `linear-gradient(135deg, #FB8C00 0%, #FFC107 100%)`;
        image.style.display = 'flex';
        image.style.alignItems = 'center';
        image.style.justifyContent = 'center';
        image.style.fontSize = '4rem';
        image.textContent = '🍽️';
    }

    const info = document.createElement('div');
    info.className = 'restaurant-info';

    const name = document.createElement('h3');
    name.className = 'restaurant-name';
    name.textContent = restaurant.name || 'Restaurant';

    const cuisine = document.createElement('p');
    cuisine.className = 'restaurant-cuisine';
    cuisine.textContent = restaurant.city ? `${restaurant.city}, ${restaurant.wilaya || restaurant.state || ''}` : (restaurant.cuisine_type || 'Various Cuisine');

    const rating = document.createElement('div');
    rating.className = 'restaurant-rating';
    const stars = '⭐'.repeat(Math.floor(restaurant.rating || 4));
    rating.textContent = `${stars} ${(restaurant.rating || 4.0).toFixed(1)}`;

    info.appendChild(name);
    info.appendChild(cuisine);
    info.appendChild(rating);

    card.appendChild(image);
    card.appendChild(info);

    // Animate in
    setTimeout(() => {
        card.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        card.style.opacity = '1';
        card.style.transform = 'translateY(0)';
    }, 100);

    return card;
}

// Show placeholder restaurants
function showPlaceholderRestaurants() {
    const restaurantsGrid = document.getElementById('restaurantsGrid');
    if (!restaurantsGrid) return;

    const placeholderRestaurants = [
        { name: 'The Gourmet Kitchen', cuisine: 'Italian Cuisine', rating: 4.8 },
        { name: 'Spice Garden', cuisine: 'Indian Cuisine', rating: 4.7 },
        { name: 'Sushi Master', cuisine: 'Japanese Cuisine', rating: 4.9 }
    ];

    restaurantsGrid.innerHTML = '';
    placeholderRestaurants.forEach((restaurant, index) => {
        const card = document.createElement('div');
        card.className = 'restaurant-card';
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';

        const image = document.createElement('div');
        image.className = 'restaurant-image';
        const gradients = [
            'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
            'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
            'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)'
        ];
        image.style.background = gradients[index];
        image.style.display = 'flex';
        image.style.alignItems = 'center';
        image.style.justifyContent = 'center';
        image.style.fontSize = '4rem';
        const emojis = ['🍝', '🍛', '🍣'];
        image.textContent = emojis[index];

        const info = document.createElement('div');
        info.className = 'restaurant-info';

        const name = document.createElement('h3');
        name.className = 'restaurant-name';
        name.textContent = restaurant.name;

        const cuisine = document.createElement('p');
        cuisine.className = 'restaurant-cuisine';
        cuisine.textContent = restaurant.cuisine;

        const rating = document.createElement('div');
        rating.className = 'restaurant-rating';
        rating.textContent = `⭐${'⭐'.repeat(Math.floor(restaurant.rating - 1))} ${restaurant.rating}`;

        info.appendChild(name);
        info.appendChild(cuisine);
        info.appendChild(rating);

        card.appendChild(image);
        card.appendChild(info);

        restaurantsGrid.appendChild(card);

        // Animate in with delay
        setTimeout(() => {
            card.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
            card.style.opacity = '1';
            card.style.transform = 'translateY(0)';
        }, index * 150);
    });
}

// Add click handlers to restaurant cards
document.addEventListener('click', (e) => {
    const restaurantCard = e.target.closest('.restaurant-card');
    if (restaurantCard) {
        // Add ripple effect
        const ripple = document.createElement('div');
        ripple.style.position = 'absolute';
        ripple.style.borderRadius = '50%';
        ripple.style.background = 'rgba(251, 140, 0, 0.3)';
        ripple.style.width = '20px';
        ripple.style.height = '20px';
        ripple.style.left = `${e.clientX - restaurantCard.getBoundingClientRect().left - 10}px`;
        ripple.style.top = `${e.clientY - restaurantCard.getBoundingClientRect().top - 10}px`;
        ripple.style.pointerEvents = 'none';
        ripple.style.animation = 'ripple 0.6s ease-out';

        restaurantCard.style.position = 'relative';
        restaurantCard.appendChild(ripple);

        setTimeout(() => ripple.remove(), 600);
    }
});

// Add ripple animation
const style = document.createElement('style');
style.textContent = `
    @keyframes ripple {
        to {
            transform: scale(20);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

// Parallax effect for hero section
window.addEventListener('scroll', () => {
    const scrolled = window.pageYOffset;
    const hero = document.querySelector('.hero');
    if (hero) {
        const heroBackground = hero.querySelector('.hero-background');
        if (heroBackground) {
            heroBackground.style.transform = `translateY(${scrolled * 0.5}px)`;
        }
    }
});

// Loading animation
window.addEventListener('load', () => {
    document.body.classList.add('loaded');

    // Fetch restaurants after page load
    setTimeout(() => {
        fetchRestaurants();
    }, 500);
});

// Add smooth scroll polyfill for older browsers
if (!('scrollBehavior' in document.documentElement.style)) {
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/gh/cferdinandi/smooth-scroll@15.0.0/dist/smooth-scroll.polyfills.min.js';
    document.head.appendChild(script);
    script.onload = () => {
        if (typeof SmoothScroll !== 'undefined') {
            new SmoothScroll('a[href*="#"]', {
                speed: 800,
                speedAsDuration: true,
                offset: 64
            });
        }
    };
}

// Performance optimization: Lazy load images
if ('IntersectionObserver' in window) {
    const imageObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const img = entry.target;
                if (img.dataset.src) {
                    img.src = img.dataset.src;
                    img.removeAttribute('data-src');
                    observer.unobserve(img);
                }
            }
        });
    });

    document.querySelectorAll('img[data-src]').forEach(img => {
        imageObserver.observe(img);
    });
}

// Console welcome message
console.log('%c🍔 Welcome to Sahla Delivery!', 'font-size: 24px; font-weight: bold; color: #FB8C00;');
console.log('%cBuilt with ❤️ for amazing food delivery experience', 'font-size: 14px; color: #666;');
