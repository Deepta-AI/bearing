package session

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

// Store keeps login sessions in Redis with a 12 hour TTL.
type Store struct{ rdb *redis.Client }

const ttl = 12 * time.Hour

func (s *Store) Put(ctx context.Context, id string, userID string) error {
	return s.rdb.Set(ctx, "sess:"+id, userID, ttl).Err()
}

func (s *Store) Get(ctx context.Context, id string) (string, error) {
	return s.rdb.Get(ctx, "sess:"+id).Result()
}
