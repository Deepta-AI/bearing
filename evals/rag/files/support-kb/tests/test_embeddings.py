from kbot.embeddings import HashingEmbedder, cosine


def test_deterministic_and_normalised():
    e = HashingEmbedder(dims=64)
    a, b = e.embed(["payroll run failed", "payroll run failed"])
    assert a == b
    assert abs(cosine(a, a) - 1.0) < 1e-9


def test_related_text_scores_higher_than_unrelated():
    e = HashingEmbedder()
    q, near, far = e.embed(["reset two factor login", "how to reset two factor login", "PF wage ceiling"])
    assert cosine(q, near) > cosine(q, far)
