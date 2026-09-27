import React from 'react';
import Header from './components/Header.jsx';

export default function App({ tenant }) {
  return (
    <div className="app">
      <Header tenant={tenant} />
      <main>
        <section className="card">
          <h2>Your next appointment</h2>
          <p className="muted">Tuesday 14 October, 10:30, Dr Rao</p>
          <button className="button">Reschedule</button>
          <a href="/appointments">All appointments</a>
        </section>
      </main>
    </div>
  );
}
