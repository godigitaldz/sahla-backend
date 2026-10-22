import Image from 'next/image';
import Link from 'next/link';
import type { Metadata } from 'next';
import './landing.css';

const appStoreUrl = 'https://apps.apple.com/us/app/sahla-food-grocery/id6760480928';
const googlePlayUrl = 'https://play.google.com/store/apps/details?id=com.godigital.sahla&pcampaignid=web_share';

export const metadata: Metadata = {
  title: 'Sahla | Order food online',
  description: 'Discover restaurants, place an order, and follow it with Sahla.',
  openGraph: {
    title: 'Sahla | Order food online',
    description: 'Discover restaurants, place an order, and follow it with Sahla.',
  },
};

const foodMoments = [
  {
    alt: 'Freshly baked pizza with basil',
    src: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=900&q=85',
  },
  {
    alt: 'Burger and fries served on a tray',
    src: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=900&q=85',
  },
  {
    alt: 'Pasta served with fresh herbs',
    src: 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=900&q=85',
  },
];

export default function HomePage() {
  return (
    <main className="landing-page" dir="ltr">
      <header className="site-header">
        <Link className="wordmark" href="/" aria-label="Sahla home">
          Sahla<span aria-hidden="true">.</span>
        </Link>
        <nav aria-label="Primary navigation">
          <a href="#how-it-works">How it works</a>
          <a href="#get-the-app">Get the app</a>
          <a className="header-action" href="#get-the-app">Download Sahla</a>
        </nav>
      </header>

      <section className="hero" aria-labelledby="hero-heading">
        <Image
          className="hero-image"
          src="https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=2200&q=88"
          alt="A shared table with fresh food"
          fill
          priority
          sizes="100vw"
        />
        <div className="hero-scrim" />
        <div className="hero-content">
          <p className="eyebrow">Food delivery, made simple</p>
          <h1 id="hero-heading">Good food, brought closer.</h1>
          <p className="hero-copy">
            Discover restaurants on Sahla, build an order that feels right, and follow it from the kitchen to your door.
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href="#get-the-app">Get the Sahla app</a>
            <a className="text-action" href="#get-the-app">
              Get the Sahla app <span aria-hidden="true">↓</span>
            </a>
          </div>
        </div>
        <a className="hero-scroll" href="#how-it-works" aria-label="Read how Sahla works">
          <span>Scroll to explore</span>
          <span aria-hidden="true" />
        </a>
      </section>

      <section className="intro" id="how-it-works" aria-labelledby="how-heading">
        <div className="section-heading">
          <p className="eyebrow">How Sahla works</p>
          <h2 id="how-heading">From craving to checkout, without the noise.</h2>
        </div>
        <div className="steps" role="list">
          <article className="step" role="listitem">
            <span className="step-number">01</span>
            <h3>Find a restaurant</h3>
            <p>Start with the restaurants available to order from online.</p>
          </article>
          <article className="step" role="listitem">
            <span className="step-number">02</span>
            <h3>Choose your meal</h3>
            <p>Browse a menu, make your choices, and review the order before checkout.</p>
          </article>
          <article className="step" role="listitem">
            <span className="step-number">03</span>
            <h3>Stay in the loop</h3>
            <p>Use Sahla to keep up with your order as it moves through preparation and delivery.</p>
          </article>
        </div>
      </section>

      <section className="food-gallery" aria-label="Food on Sahla">
        <div className="gallery-intro">
          <p className="eyebrow">For the table</p>
          <h2>Whatever you are in the mood for.</h2>
          <p>Open Sahla when dinner needs less planning and more appetite.</p>
          <a className="inline-link" href="#get-the-app">
            Get the Sahla app <span aria-hidden="true">→</span>
          </a>
        </div>
        <div className="gallery-grid">
          {foodMoments.map((food, index) => (
            <figure className={`food-photo food-photo-${index + 1}`} key={food.src}>
              <Image src={food.src} alt={food.alt} fill sizes="(max-width: 760px) 100vw, 33vw" />
            </figure>
          ))}
        </div>
      </section>

      <section className="app-section" id="get-the-app" aria-labelledby="app-heading">
        <div>
          <p className="eyebrow">Sahla on your phone</p>
          <h2 id="app-heading">Keep your next order within reach.</h2>
        </div>
        <div className="app-content">
          <p>Download Sahla to browse, order, and receive order updates from one place.</p>
          <div className="store-links">
            <a href={appStoreUrl} target="_blank" rel="noreferrer" className="store-link">
              <span className="store-label">Download on the</span>
              <span className="store-name">App Store</span>
            </a>
            <a href={googlePlayUrl} target="_blank" rel="noreferrer" className="store-link">
              <span className="store-label">Get it on</span>
              <span className="store-name">Google Play</span>
            </a>
          </div>
        </div>
      </section>

      <footer className="site-footer">
        <Link className="wordmark" href="/" aria-label="Sahla home">
          Sahla<span aria-hidden="true">.</span>
        </Link>
        <div className="footer-links">
          <a href="/privacy-policy">Privacy</a>
          <a href="/terms-of-service">Terms</a>
          <a href="/delete-account">Delete account</a>
        </div>
        <p>© {new Date().getFullYear()} Sahla Delivery</p>
      </footer>
    </main>
  );
}
