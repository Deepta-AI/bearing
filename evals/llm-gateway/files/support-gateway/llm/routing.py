"""Loads llm/routing.yaml into Route objects."""

import os
from dataclasses import dataclass

import yaml

HERE = os.path.dirname(__file__)


class UnknownFeature(Exception):
    pass


@dataclass(frozen=True)
class Price:
    input_per_m: float
    output_per_m: float


@dataclass(frozen=True)
class Route:
    feature: str
    model: str
    provider: str
    max_tokens: int
    timeout_s: float
    enabled: bool = True


class Routing:
    def __init__(self, path: str = os.path.join(HERE, "routing.yaml")):
        with open(path, encoding="utf-8") as fh:
            self.raw = yaml.safe_load(fh)
        self.prices = {
            name: Price(spec["input_per_m"], spec["output_per_m"])
            for name, spec in self.raw["models"].items()
        }

    def route(self, feature: str) -> Route:
        spec = self.raw["routes"].get(feature)
        if spec is None:
            raise UnknownFeature(feature)
        tier = self.raw["tiers"][spec["tier"]]
        model = spec.get("model", tier["model"])
        return Route(
            feature=feature,
            model=model,
            provider=self.raw["models"][model]["provider"],
            max_tokens=spec.get("max_tokens", tier["max_tokens"]),
            timeout_s=spec.get("timeout_s", tier["timeout_s"]),
            enabled=spec.get("enabled", True),
        )
