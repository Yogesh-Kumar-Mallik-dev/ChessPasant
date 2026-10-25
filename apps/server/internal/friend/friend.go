package friend

import (
	"context"
	"errors"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type FriendshipStatus string

const (
	FriendshipPending  FriendshipStatus = "pending"
	FriendshipAccepted FriendshipStatus = "accepted"
	FriendshipDeclined FriendshipStatus = "declined"
)

type Friendship struct {
	ID                primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	RequesterID       primitive.ObjectID `bson:"requesterId" json:"requesterId"`
	RequesterUsername string             `bson:"requesterUsername" json:"requesterUsername"`
	RequesterAvatar   string             `bson:"requesterAvatar,omitempty" json:"requesterAvatar,omitempty"`
	AddresseeID       primitive.ObjectID `bson:"addresseeId" json:"addresseeId"`
	AddresseeUsername string             `bson:"addresseeUsername" json:"addresseeUsername"`
	AddresseeAvatar   string             `bson:"addresseeAvatar,omitempty" json:"addresseeAvatar,omitempty"`
	Status            FriendshipStatus   `bson:"status" json:"status"`
	CreatedAt         time.Time          `bson:"createdAt" json:"createdAt"`
	UpdatedAt         time.Time          `bson:"updatedAt" json:"updatedAt"`
}

type FriendItem struct {
	ID           string    `json:"id"`
	FriendshipID string    `json:"friendshipId"`
	Username     string    `json:"username"`
	Avatar       string    `json:"avatar"`
	Rating       int       `json:"rating"`
	CreatedAt    time.Time `json:"createdAt"`
}

type ChallengeStatus string

const (
	ChallengePending  ChallengeStatus = "pending"
	ChallengeAccepted ChallengeStatus = "accepted"
	ChallengeDeclined ChallengeStatus = "declined"
	ChallengeCanceled ChallengeStatus = "canceled"
)

type Challenge struct {
	ID                 primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	ChallengerID       primitive.ObjectID `bson:"challengerId" json:"challengerId"`
	ChallengerUsername string             `bson:"challengerUsername" json:"challengerUsername"`
	ChallengerAvatar   string             `bson:"challengerAvatar,omitempty" json:"challengerAvatar,omitempty"`
	ChallengerRating   int                `bson:"challengerRating,omitempty" json:"challengerRating"`
	ChallengedID       primitive.ObjectID `bson:"challengedId" json:"challengedId"`
	ChallengedUsername string             `bson:"challengedUsername" json:"challengedUsername"`
	ChallengedAvatar   string             `bson:"challengedAvatar,omitempty" json:"challengedAvatar,omitempty"`
	ChallengedRating   int                `bson:"challengedRating,omitempty" json:"challengedRating"`
	InitialSeconds     int                `bson:"initial" json:"initial"`
	Increment          int                `bson:"increment" json:"increment"`
	Rated              bool               `bson:"rated" json:"rated"`         // with ELO vs without ELO
	ColorPref          string             `bson:"colorPref" json:"colorPref"` // "random", "white", "black"
	Status             ChallengeStatus    `bson:"status" json:"status"`
	GameID             string             `bson:"gameId,omitempty" json:"gameId,omitempty"`
	CreatedAt          time.Time          `bson:"createdAt" json:"createdAt"`
	UpdatedAt          time.Time          `bson:"updatedAt" json:"updatedAt"`
}

type Repository interface {
	SendFriendRequest(ctx context.Context, f *Friendship) error
	RespondFriendRequest(ctx context.Context, id, addresseeID primitive.ObjectID, accept bool) (*Friendship, error)
	RemoveFriend(ctx context.Context, userA, userB primitive.ObjectID) error
	ListFriends(ctx context.Context, userID primitive.ObjectID) ([]Friendship, error)
	ListPendingRequests(ctx context.Context, userID primitive.ObjectID) ([]Friendship, []Friendship, error)
	GetFriendship(ctx context.Context, userA, userB primitive.ObjectID) (*Friendship, error)

	CreateChallenge(ctx context.Context, c *Challenge) error
	GetChallenge(ctx context.Context, id primitive.ObjectID) (*Challenge, error)
	UpdateChallenge(ctx context.Context, id primitive.ObjectID, status ChallengeStatus, gameID string) error
	ListPendingChallenges(ctx context.Context, userID primitive.ObjectID) ([]*Challenge, []*Challenge, error)
	EnsureIndexes(ctx context.Context) error
}

type MongoRepository struct {
	friendships *mongo.Collection
	challenges  *mongo.Collection
}

func NewMongoRepository(db *mongo.Database) *MongoRepository {
	return &MongoRepository{
		friendships: db.Collection("friendships"),
		challenges:  db.Collection("challenges"),
	}
}

func (r *MongoRepository) EnsureIndexes(ctx context.Context) error {
	fModels := []mongo.IndexModel{
		{
			Keys: bson.D{
				{Key: "requesterId", Value: 1},
				{Key: "addresseeId", Value: 1},
			},
			Options: options.Index().SetUnique(true),
		},
		{
			Keys: bson.D{{Key: "addresseeId", Value: 1}, {Key: "status", Value: 1}},
		},
		{
			Keys: bson.D{{Key: "requesterId", Value: 1}, {Key: "status", Value: 1}},
		},
	}
	_, _ = r.friendships.Indexes().CreateMany(ctx, fModels)

	cModels := []mongo.IndexModel{
		{
			Keys: bson.D{{Key: "challengedId", Value: 1}, {Key: "status", Value: 1}},
		},
		{
			Keys: bson.D{{Key: "challengerId", Value: 1}, {Key: "status", Value: 1}},
		},
		{
			Keys:    bson.D{{Key: "createdAt", Value: 1}},
			Options: options.Index().SetExpireAfterSeconds(3600), // Auto-expire old challenges after 1 hour
		},
	}
	_, _ = r.challenges.Indexes().CreateMany(ctx, cModels)
	return nil
}

func (r *MongoRepository) SendFriendRequest(ctx context.Context, f *Friendship) error {
	now := time.Now().UTC()
	f.CreatedAt = now
	f.UpdatedAt = now
	f.Status = FriendshipPending

	// Check if already exists in either direction
	existing, err := r.GetFriendship(ctx, f.RequesterID, f.AddresseeID)
	if err == nil && existing != nil {
		if existing.Status == FriendshipAccepted {
			return errors.New("already friends")
		}
		if existing.Status == FriendshipPending {
			// If already requested by the other party, auto-accept!
			if existing.RequesterID == f.AddresseeID {
				_, err := r.RespondFriendRequest(ctx, existing.ID, f.RequesterID, true)
				return err
			}
			return errors.New("friend request already pending")
		}
		// If previously declined, update status back to pending
		update := bson.M{
			"$set": bson.M{
				"requesterId":       f.RequesterID,
				"requesterUsername": f.RequesterUsername,
				"requesterAvatar":   f.RequesterAvatar,
				"addresseeId":       f.AddresseeID,
				"addresseeUsername": f.AddresseeUsername,
				"addresseeAvatar":   f.AddresseeAvatar,
				"status":            FriendshipPending,
				"updatedAt":         now,
			},
		}
		_, err = r.friendships.UpdateByID(ctx, existing.ID, update)
		return err
	}

	f.ID = primitive.NewObjectID()
	_, err = r.friendships.InsertOne(ctx, f)
	return err
}

func (r *MongoRepository) RespondFriendRequest(ctx context.Context, id, addresseeID primitive.ObjectID, accept bool) (*Friendship, error) {
	now := time.Now().UTC()
	newStatus := FriendshipDeclined
	if accept {
		newStatus = FriendshipAccepted
	}

	filter := bson.M{
		"_id":         id,
		"addresseeId": addresseeID,
		"status":      FriendshipPending,
	}
	update := bson.M{
		"$set": bson.M{
			"status":    newStatus,
			"updatedAt": now,
		},
	}

	var updated Friendship
	opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
	err := r.friendships.FindOneAndUpdate(ctx, filter, update, opts).Decode(&updated)
	if err != nil {
		return nil, errors.New("friend request not found or unauthorized")
	}
	return &updated, nil
}

func (r *MongoRepository) RemoveFriend(ctx context.Context, userA, userB primitive.ObjectID) error {
	filter := bson.M{
		"$or": []bson.M{
			{"requesterId": userA, "addresseeId": userB},
			{"requesterId": userB, "addresseeId": userA},
		},
	}
	_, err := r.friendships.DeleteOne(ctx, filter)
	return err
}

func (r *MongoRepository) ListFriends(ctx context.Context, userID primitive.ObjectID) ([]Friendship, error) {
	filter := bson.M{
		"status": FriendshipAccepted,
		"$or": []bson.M{
			{"requesterId": userID},
			{"addresseeId": userID},
		},
	}
	opts := options.Find().SetSort(bson.D{{Key: "updatedAt", Value: -1}})
	cur, err := r.friendships.Find(ctx, filter, opts)
	if err != nil {
		return nil, err
	}
	defer cur.Close(ctx)

	var list []Friendship
	if err := cur.All(ctx, &list); err != nil {
		return nil, err
	}
	return list, nil
}

func (r *MongoRepository) ListPendingRequests(ctx context.Context, userID primitive.ObjectID) ([]Friendship, []Friendship, error) {
	// Incoming
	inFilter := bson.M{
		"addresseeId": userID,
		"status":      FriendshipPending,
	}
	inCur, err := r.friendships.Find(ctx, inFilter)
	if err != nil {
		return nil, nil, err
	}
	defer inCur.Close(ctx)
	var incoming []Friendship
	_ = inCur.All(ctx, &incoming)

	// Outgoing
	outFilter := bson.M{
		"requesterId": userID,
		"status":      FriendshipPending,
	}
	outCur, err := r.friendships.Find(ctx, outFilter)
	if err != nil {
		return nil, nil, err
	}
	defer outCur.Close(ctx)
	var outgoing []Friendship
	_ = outCur.All(ctx, &outgoing)

	return incoming, outgoing, nil
}

func (r *MongoRepository) GetFriendship(ctx context.Context, userA, userB primitive.ObjectID) (*Friendship, error) {
	filter := bson.M{
		"$or": []bson.M{
			{"requesterId": userA, "addresseeId": userB},
			{"requesterId": userB, "addresseeId": userA},
		},
	}
	var f Friendship
	err := r.friendships.FindOne(ctx, filter).Decode(&f)
	if err != nil {
		return nil, err
	}
	return &f, nil
}

func (r *MongoRepository) CreateChallenge(ctx context.Context, c *Challenge) error {
	now := time.Now().UTC()
	c.ID = primitive.NewObjectID()
	c.CreatedAt = now
	c.UpdatedAt = now
	c.Status = ChallengePending
	_, err := r.challenges.InsertOne(ctx, c)
	return err
}

func (r *MongoRepository) GetChallenge(ctx context.Context, id primitive.ObjectID) (*Challenge, error) {
	var c Challenge
	err := r.challenges.FindOne(ctx, bson.M{"_id": id}).Decode(&c)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *MongoRepository) UpdateChallenge(ctx context.Context, id primitive.ObjectID, status ChallengeStatus, gameID string) error {
	update := bson.M{
		"$set": bson.M{
			"status":    status,
			"updatedAt": time.Now().UTC(),
		},
	}
	if gameID != "" {
		update["$set"].(bson.M)["gameId"] = gameID
	}
	_, err := r.challenges.UpdateByID(ctx, id, update)
	return err
}

func (r *MongoRepository) ListPendingChallenges(ctx context.Context, userID primitive.ObjectID) ([]*Challenge, []*Challenge, error) {
	// Only fetch challenges created within the last 15 minutes
	cutoff := time.Now().UTC().Add(-15 * time.Minute)

	inFilter := bson.M{
		"challengedId": userID,
		"status":       ChallengePending,
		"createdAt":    bson.M{"$gte": cutoff},
	}
	inCur, err := r.challenges.Find(ctx, inFilter, options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}))
	if err != nil {
		return nil, nil, err
	}
	defer inCur.Close(ctx)
	var incoming []*Challenge
	_ = inCur.All(ctx, &incoming)

	outFilter := bson.M{
		"challengerId": userID,
		"status":       bson.M{"$in": []ChallengeStatus{ChallengePending, ChallengeAccepted}},
		"createdAt":    bson.M{"$gte": cutoff},
	}
	outCur, err := r.challenges.Find(ctx, outFilter, options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}))
	if err != nil {
		return nil, nil, err
	}
	defer outCur.Close(ctx)
	var outgoing []*Challenge
	_ = outCur.All(ctx, &outgoing)

	return incoming, outgoing, nil
}
